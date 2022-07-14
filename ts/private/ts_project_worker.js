const fs = require('fs');
const ts = require('typescript');
const path = require('path');
const worker = require('@bazel/worker');
const MNEMONIC = 'TsProject';

function noop() {}

/** Timing */
function timingStart(label) {
    ts.performance.mark(`before${label}`);
}
function timingEnd(label) {
    ts.performance.mark(`after${label}`);
    ts.performance.measure(`${MNEMONIC} ${label}`, `before${label}`, `after${label}`);
}

function getArgsFromParamFile() {
    let paramFilePath = process.argv[process.argv.length - 1];
    if (paramFilePath.startsWith('@')) {
        // paramFilePath is relative to execroot but we are in bazel-out so we have to go three times up to reach execroot.
        // paramFilePath = bazel-out/darwin_arm64-fastbuild/bin/0.params
        // currentDir =  bazel-out/darwin_arm64-fastbuild/bin
        paramFilePath = path.resolve('..', '..', '..', paramFilePath.slice(1));
    }
    return fs.readFileSync(paramFilePath).toString().trim().split('\n');
}

function createFilesystemTree(root, inputs) {
    const hashes = new Map();
    const tree = {};

    for (const p in inputs) {
        add(p, inputs[p]);
    }

    function getNode(p) {
        const parts = p.split(path.sep);
        let backtrack = tree;
    
        for (const part of parts) {
            backtrack = backtrack[part];
            if (!backtrack) {
                return undefined;
            }
            if (backtrack.symlinkTo) {
                backtrack = getNode(backtrack.symlinkTo);
            }
        }
        return backtrack;
    }

    function add(p, hash) {
        const parts = p.split(path.sep);
        let backtrack = tree;
        for (const part of parts) {
            if (typeof backtrack[part] != "object") {
                backtrack[part] = {};
            }
            backtrack = backtrack[part];
        }

        // Digest is empty when the input is a symlink which we use as an indicator to limit number of 
        // realpath calls we make.
        // See: https://github.com/bazelbuild/bazel/pull/14002#issuecomment-977790796 for what it can be empty.
        if (hash == null) {
            const realpath = ts.sys.realpath(path.join(root, p));
            const relative = path.relative(root, realpath);
            if (relative != p) {
                backtrack.symlinkTo = relative;
            }
        }
        hashes.set(p, hash);
    }

    function remove(p) {
        const parts = p.split(path.sep);
        const lastPart = parts.pop();
        let backtrack = tree;
        for (const part of parts) {
            if (typeof backtrack[part] == "object") {
                backtrack = backtrack[part];
            } else {
                return // couldn't find it.
            }
        }
        // Bazel never reports empty TreeArtifacts within the inputs map. Meaning if a directory contains nothing then bazel will never tell us about that input.
        // 
        // Ideally, after a removal operation we should be checking for orphan parent nodes within the tree of that given path and remove them.
        // This could be done by to walking up nodes and removing them if they are being orphaned as a result of this action. However, since this would 
        // be a costly operation given the recursive calls that we have to do, we decide to do nothing about them given that 
        // this neither a correctness nor reproducibility issue. 
        // Reason behind this is tsc itself. It does not affect tsc if an empty folder is there or not, as it only looks for `<name>/index.ts` or `<name>.ts`
        delete backtrack[lastPart]
        hashes.delete(p)
    }

    function fileExists(p) {
        const node = getNode(p);
        return typeof node == "object" && Object.keys(node).length == 0;
    }

    function directoryExists(p) {
        const node = getNode(p);
        return typeof node == "object" && Object.keys(node).length > 0;
    }

    function readDirectory(p, extensions, exclude, include, depth) {
        const node = getNode(p);
        if (!node) {
            return []
        }
        return Object.keys(node);
    }

    function getDirectories(p) {
        const node = getNode(p);
        if (!node) {
            return []
        }
        const dirs = [];
        for (const np in node) {
            if (Object.keys(node[np]).length > 0) {
                dirs.push(np);
            }
        }
        return dirs
    }

    return { add, remove, fileExists, directoryExists, readDirectory, getDirectories }
}

function isExternalLib(path) {
    return  path.includes('external') && 
            path.includes('typescript@') && 
            path.includes('node_modules/typescript/lib')
}

const libCache = new Map();

// TODO: support overloading with https://github.com/microsoft/TypeScript/blob/ab2523bbe0352d4486f67b73473d2143ad64d03d/src/compiler/builder.ts#L1008
function createEmitAndLibCacheAndDiagnosticsProgram(
    rootNames,
    options,
    host,
    oldProgram,
    configFileParsingDiagnostics,
    projectReferences
) {
    const builder = ts.createEmitAndSemanticDiagnosticsBuilderProgram(
        rootNames,
        options,
        host,
        oldProgram,
        configFileParsingDiagnostics,
        projectReferences
    );

    /** Emit Cache */
    /** @type {Map} */
    const emittedFiles = (host.emittedFiles = host.emittedFiles || new Map());
    /** @type {Map} */
    const emittingMap = (host.emittedFilesWeak = host.emittedFilesWeak || new Map());

    const emit = builder.emit;
    builder.emit = (targetSourceFile, writeFile, cancellationToken, emitOnlyDtsFiles, customTransformers) => {
        writeFile = writeFile || host.writeFile;
        if (!targetSourceFile) {
            for (const [path, content] of emittedFiles.entries()) {
                const sourcePath = emittingMap.get(path);
                if (!builder.getSourceFile(sourcePath)) {
                    emittedFiles.delete(path);
                    emittingMap.delete(path);
                } else {
                    writeFile(path, content);
                }
            }
        }

        const writeF = (fileName, data, writeByteOrderMark, onError, sourceFiles) => {
            writeFile(fileName, data, writeByteOrderMark, onError, sourceFiles);
            if (sourceFiles && sourceFiles.length !== 0) {
                host.debuglog?.(`putting ${fileName} into emit cache`);
                emittingMap.set(fileName, sourceFiles[0].fileName);
                emittedFiles.set(fileName, data);
            }
        };
        return emit(targetSourceFile, writeF, cancellationToken, emitOnlyDtsFiles, customTransformers);
    };

    /** Lib Cache */
    const getSourceFile = host.getSourceFile;
    host.getSourceFile = (fileName) => {
        if (libCache.has(fileName)) {
            host.debuglog?.(`cache hit for default lib ${fileName}`)
            return libCache.get(fileName);
        }
        const sf = getSourceFile(fileName);
        if (sf && isExternalLib(fileName)) {
            host.debuglog?.(`putting default lib ${fileName} into cache.`)
            libCache.set(fileName, sf);
        }
        return sf;
    }

    return builder;
}

/** @type {ts.FormatDiagnosticsHost} */
const formatDiagnosticHost = {
    getCanonicalFileName: (path) => path,
    getCurrentDirectory: ts.sys.getCurrentDirectory,
    getNewLine: () => ts.sys.newLine,
};

function printDiagnostics(diagnostics) {
    worker.log('');
    worker.log(ts.formatDiagnostics(diagnostics, formatDiagnosticHost));
}

/** @type {Map<string, ReturnType<createProgram> & {previousInputs?: import("@bazel/worker").Inputs}>} */
const workers = new Map();

function createProgram(args, initialInputs) {
    const {options} = ts.parseCommandLine(args);
    const compilerOptions = {...options}

    const bin = process.cwd();
    const execRoot = path.resolve(bin, '..', '..', '..');
    const tsconfig = path.relative(execRoot, path.resolve(bin, options.project));

    const directoryWatchers = new Map();
    const fileWatchers = new Map();

    const filesystemTree = createFilesystemTree(execRoot, initialInputs);

    const outputs = new Set();

    const taskQueue = new Set();

    /** @type {ts.System} */
    const strictSys = {
        write: worker.log,
        writeOutputIsTTY: () => false,
        setTimeout: setTimeout,
        clearTimeout: clearTimeout, 
        fileExists: fileExists,
        readFile: readFile,
        readDirectory: readDirectory,
        directoryExists: directoryExists,
        getDirectories: getDirectories,
        watchFile: watchFile,
        watchDirectory: watchDirectory,
        exit: noop
    };
    const sys = {
        ...ts.sys,
        ...strictSys,
    };

    enablePerformanceAndTracingIfNeeded();
    updateOutputs();

    const host = ts.createWatchCompilerHost(
        compilerOptions.project,
        compilerOptions,
        sys,
        createEmitAndLibCacheAndDiagnosticsProgram,
        noop,
        noop
    );

    host.invalidate = invalidate;
    host.applyChanges = applyChanges;
    host.debuglog = debuglog;

    debuglog(`tsconfig: ${tsconfig}`);
    debuglog(`execroot ${execRoot}`);

    const program = ts.createWatchProgram(host);

    return { host, program, checkAndApplyArgs };

    function setTimeout(cb) {
        taskQueue.add(cb);
        return cb;
    }

    function clearTimeout(cb) {
        taskQueue.delete(cb)
    }

    function applyChanges() {
        debuglog("Applying changes");
        for (const task of taskQueue) {
            taskQueue.delete(task);
            task();
        }
    }

    function enablePerformanceAndTracingIfNeeded() {
        if (compilerOptions.extendedDiagnostics) {
            ts.performance.enable();
        }
        // tracing is only available in 4.1 and above
        // See: https://github.com/microsoft/TypeScript/wiki/Performance-Tracing
        if (compilerOptions.generateTrace && ts.startTracing) {
            ts.startTracing('build', compilerOptions.generateTrace);
        }
    }

    function updateOutputs() {
        outputs.clear();
        if (compilerOptions.tsBuildInfoFile) {
            const p = path.relative(execRoot, path.join(bin, compilerOptions.tsBuildInfoFile));
            outputs.add(p);
        }
    }

    function checkAndApplyArgs(newArgs) {
        // This function works based on the assumption that parseConfigFile of createWatchProgram
        // will always reread compilerOptions with its reference.
        // See: https://github.com/microsoft/TypeScript/blob/2ecde2718722d6643773d43390aa57c3e3199365/src/compiler/watchPublic.ts#L735
        // and: https://github.com/microsoft/TypeScript/blob/2ecde2718722d6643773d43390aa57c3e3199365/src/compiler/watchPublic.ts#L296
        if (args.join(' ') != newArgs.join(' ')) {
            const {options} = ts.parseCommandLine(newArgs);
            for (const key in compilerOptions) {
                delete compilerOptions[key];
            }
            for (const key in options) {
                compilerOptions[key] = options[key];
            }
            enablePerformanceAndTracingIfNeeded();
            updateOutputs();
            // invalidating tsconfig will cause parseConfigFile to be invoked
            invalidate(tsconfig, ts.FileWatcherEventKind.Changed);
            args = newArgs;
        }
    }

    function debuglog(message) {
        compilerOptions.extendedDiagnostics && host.trace?.(message)
    }

    function getDirectoryWatcherForPath(fileName) {
        const p = path.dirname(fileName); 
        const callbacks = directoryWatchers.get(p);
        if (callbacks) {
            return (filePath) => {
                for (const callback of callbacks) {
                    callback(filePath)
                }
            };
        }
    }

    function readFile(filePath, encoding) {
        const relative = path.relative(execRoot, filePath);
        // external lib are transitive sources thus not listed in the inputs map reported by bazel.
        if (!filesystemTree.fileExists(path.relative(execRoot, filePath)) && !isExternalLib(filePath) && !outputs.has(relative)) {
            throw new Error(`tsc tried to read file that wasn't an input to it.`);
        }
        return ts.sys.readFile(filePath, encoding);
    }

    function directoryExists(directoryPath) {
        if (!directoryPath.startsWith(bin)) {
            return false;
        }
        return filesystemTree.directoryExists(path.relative(execRoot, directoryPath));
    }

    function getDirectories(directoryPath) {
        return filesystemTree.getDirectories(path.relative(execRoot, directoryPath));
    }

    function fileExists(filePath) {
        return filesystemTree.fileExists(path.relative(execRoot, filePath));
    }

    function readDirectory(directoryPath, extensions, exclude, include, depth) {
        return filesystemTree.readDirectory(
            path.relative(execRoot, directoryPath), 
            extensions, exclude, include, depth
        ).map(p => path.isAbsolute(p) ? p : path.join(execRoot, p))
    }

    function invalidate(filePath, kind, digest) {
        if (filePath.endsWith('.params')) return;
        debuglog(`invalidate ${filePath} : ${ts.FileWatcherEventKind[kind]}`);

        if (kind === ts.FileWatcherEventKind.Created) {
            filesystemTree.add(filePath, digest);
        } else if (kind === ts.FileWatcherEventKind.Deleted) {
            filesystemTree.remove(filePath);
        }

        // We need to signal that directory containing the missing sources is present to properly
        // invalidate failed lookups cache of tsc.
        // 
        // When `bazel-out/darwin_arm64-fastbuild/bin/feature1/index.d.ts` invalidated with kind 
        // we need to do following;
        //
        // First, Get the directory watcher for `bazel-out/darwin_arm64-fastbuild/bin/feature1/index.d.ts`
        // and invoke it with `bazel-out/darwin_arm64-fastbuild/bin/feature1/index.d.ts`
        // 
        // Then, in case the directory containing index.d.ts is in failed lookups 
        // we need repeat the first step for containing directory as well.
        // Get the directory watcher for `bazel-out/darwin_arm64-fastbuild/bin/feature1`
        // and invoke it with `bazel-out/darwin_arm64-fastbuild/bin/feature1`
        const dir = path.dirname(filePath);
        getDirectoryWatcherForPath(dir)?.(dir);

        getDirectoryWatcherForPath(filePath)?.(filePath);

        let callback = fileWatchers.get(filePath);
        callback?.(kind);
    }

    function watchDirectory(directoryPath, callback, recursive, options) {
        directoryPath = path.relative(execRoot, directoryPath);
        // since rules_js runs everything under bazel-out we shouldn't care about anything outside of it.
        if (!directoryPath.startsWith('bazel-out')) {
            return { close: noop };
        }
        debuglog(`watchDirectory ${directoryPath}`);

        const cb = (input) => callback(path.join(execRoot, input))

        const callbacks = directoryWatchers.get(directoryPath) || new Set();
        callbacks.add(cb)
        directoryWatchers.set(directoryPath, callbacks);

        return {
            close: () => {
                const callbacks = directoryWatchers.get(directoryPath);
                callbacks.delete(cb);
                if (callbacks.size === 0) {
                    directoryWatchers.delete(directoryPath)
                }
            },
        };
    }

    function watchFile(filePath, callback, interval) {
        debuglog(`watchFile ${filePath} ${interval}`);
        const relativeFilePath = path.relative(execRoot, filePath);
        fileWatchers.set(relativeFilePath, (kind) => callback(filePath, kind));
        return { close: () => fileWatchers.delete(relativeFilePath) };
    }
}


function getOrCreateWorker(args, inputs) {
    const project = args[args.indexOf('--project') + 1]
    const outDir = args[args.lastIndexOf("--outDir") + 1]
    const declarationDir = args[args.lastIndexOf("--declarationDir") + 1]
    const rootDir = args[args.lastIndexOf("--rootDir") + 1]
    const key = `${project} @ ${outDir} @ ${declarationDir} @ ${rootDir}`
    if (!workers.has(key)) {
        const { program, host, checkAndApplyArgs } = createProgram(args, inputs);
        host.debuglog(`Created a new worker for ${key}`);
        workers.set(key, {
            program,
            host,
            checkAndApplyArgs
        });
    }
    return workers.get(key);
}


function emit(args, inputs) {
    const _worker = getOrCreateWorker(args, inputs);

    const host = _worker.host;
    const lastRequestTimestamp = Date.now();
    const previousInputs = _worker.previousInputs;

    timingStart('checkAndApplyArgs');
    _worker.checkAndApplyArgs(args);
    timingEnd('checkAndApplyArgs');


    if (previousInputs) {
        timingStart(`invalidate`);
        for (const input of Object.keys(previousInputs)) {
            if (!inputs[input]) {
                host.invalidate(input, ts.FileWatcherEventKind.Deleted);
            }
        }
        for (const [input, digest] of Object.entries(inputs)) {
            if (!(input in previousInputs)) {
                host.invalidate(input, ts.FileWatcherEventKind.Created, digest);
                host.applyChanges();
                host.invalidate(input, ts.FileWatcherEventKind.Changed, digest);
            } else if (previousInputs[input] != digest) {
                host.invalidate(input, ts.FileWatcherEventKind.Changed, digest);
            }
        }
        timingEnd('invalidate');
    }

    timingStart('applyChanges')
    host.applyChanges();
    timingEnd('applyChanges')

    timingStart('getProgram');
    const program = _worker.program.getCurrentProgram()
    timingEnd('getProgram');

    const cancellationToken = {
        isCancellationRequested: function (timestamp) {
            return timestamp !== lastRequestTimestamp;
        }.bind(null, lastRequestTimestamp),
        throwIfCancellationRequested: function (timestamp) {
            if (timestamp !== lastRequestTimestamp) {
                throw new ts.OperationCanceledException();
            }
        }.bind(null, lastRequestTimestamp),
    };

    timingStart('emit');
    const result = program.emit(undefined, undefined, cancellationToken);
    timingEnd('emit');

    timingStart('diagnostics');
    const diagnostics = ts.getPreEmitDiagnostics(program, undefined, cancellationToken).concat(result?.diagnostics);
    timingEnd('diagnostics');

    const succeded = !result.emitSkipped && result?.diagnostics.length === 0 && diagnostics.length === 0;

    if (!succeded) {
        printDiagnostics(diagnostics);
    }

    _worker.previousInputs = inputs;

    if (ts.performance.isEnabled()) {
        ts.performance.forEachMeasure((name, duration) => host.debuglog(`${name} time: ${duration}`));
        // Disabling performance will reset counters for the next compilation
        ts.performance.disable()
    }

    if (ts.tracing) {
        ts.tracing.stopTracing()
    }

    return succeded;
}

// Based on https://github.com/microsoft/TypeScript/blob/3fd8a6e44341f14681aa9d303dc380020ccb2147/src/executeCommandLine/executeCommandLine.ts#L465
function emitOnce(args) {
    const currentDirectory = ts.sys.getCurrentDirectory();
    const reportDiagnostic = ts.createDiagnosticReporter({ ...ts.sys, write: worker.log });
    const commandLine = ts.parseCommandLine(args);
    const extendedConfigCache = new ts.Map();
    const commandLineOptions = ts.convertToOptionsWithAbsolutePaths(commandLine.options, (fileName) =>
        ts.getNormalizedAbsolutePath(fileName, currentDirectory)
    );
    const configParseResult = ts.parseConfigFileWithSystem(
        commandLine.options.project,
        commandLineOptions,
        extendedConfigCache,
        commandLine.watchOptions,
        ts.sys,
        reportDiagnostic
    );
    const program = ts.createProgram({
        options: configParseResult.options,
        rootNames: configParseResult.fileNames,
        projectReferences: configParseResult.projectReferences,
        configFileParsingDiagnostics: configParseResult.errors,
    });
    const result = program.emit();
    const diagnostics = ts.getPreEmitDiagnostics(program).concat(result?.diagnostics);
    const succeded = !result.emitSkipped && result?.diagnostics.length === 0 && diagnostics.length === 0;

    if (!succeded) {
        printDiagnostics(diagnostics);
    }

    return succeded;
}

if (require.main === module && worker.runAsWorker(process.argv)) {
    worker.log(`Running ${MNEMONIC} as a Bazel worker`);
    worker.runWorkerLoop(emit);
} else if (require.main === module) {
    worker.log(`WARNING: Running ${MNEMONIC} as a standalone process`);
    worker.log(
        `Started a standalone process to perform this action but this might lead to some unexpected behavior with tsc due to being run non-sandboxed.`
    );
    worker.log(
        `Your build might be misconfigured, try putting "build --strategy=${MNEMONIC}=worker" into your .bazelrc or add "supports_workers = False" attribute into this ts_project target.`
    );
    const args = getArgsFromParamFile();
    if (!emitOnce(args)) {
        process.exit(1);
    }
}

module.exports = {createFilesystemTree: createFilesystemTree};