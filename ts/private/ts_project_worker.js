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
            host.debuglog?.(`putting ${fileName} into emit cache`);
            emittingMap.set(fileName, sourceFiles[0].fileName);
            emittedFiles.set(fileName, data);
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
        if (sf && 
            fileName.includes('external') && 
            fileName.includes('typescript@') && 
            fileName.includes('node_modules/typescript/lib')
        ) {
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

function isAncestorDirectory(ancestor, child) {
    const ancestorChunks = ancestor.split(path.sep).filter((i) => !!i);
    const childChunks = child.split(path.sep).filter((i) => !!i);
    return ancestorChunks.every((chunk, i) => childChunks[i] === chunk);
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
    const knownInputs = new Set(initialInputs);

    let applyChanges = () => {}
    /** @type {ts.System} */
    const strictSys = {
        write: worker.log,
        writeOutputIsTTY: () => false,
        setTimeout: (cb) => applyChanges = () => cb(),
        clearTimeout: () => applyChanges = () => {},
        fileExists: fileExists,
        readFile: readFile,
        writeFile: writeFile,
        readDirectory: readDirectory,
        directoryExists: directoryExists,
        getDirectories: getDirectories,
        watchFile: watchFile,
        watchDirectory: watchDirectory,
    };
    const sys = {
        ...ts.sys,
        ...strictSys,
    };

    enablePerformanceAndTracingIfNeeded();

    const host = ts.createWatchCompilerHost(
        compilerOptions.project,
        compilerOptions,
        sys,
        createEmitAndLibCacheAndDiagnosticsProgram,
        noop,
        noop
    );

    host.invalidate = invalidate;
    host.applyChanges = () => applyChanges();
    host.debuglog = debuglog;

    debuglog(`tsconfig: ${tsconfig}`);
    debuglog(`execroot ${execRoot}`);

    const program = ts.createWatchProgram(host);

    return { host, program, checkAndApplyArgs };

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
            // invalidating tsconfig will cause parseConfigFile to be invoked
            invalidate(tsconfig, ts.FileWatcherEventKind.Changed);
            args = newArgs;
        }
    }

    function debuglog(message) {
        compilerOptions.extendedDiagnostics && host.trace?.(message)
    }

    function getDirectoryWatcherForPath(path) {
        for (const [directory, callbacks] of directoryWatchers.entries()) {
            if (isAncestorDirectory(directory, path)) {
                debuglog(`found a directory watcher for ${path} ${directory}`);
                return (filePath) => {
                    for (const callback of callbacks) {
                        callback(filePath)
                    }
                };
            }
        }
    }

    function writeFile(path, data, writeByteOrderMark) {
        debuglog(`writeFile ${path}`);
        ts.sys.writeFile(path, data, writeByteOrderMark);
    }

    function readFile(filePath, encoding) {
        debuglog(`readFile ${filePath}`);
        const relative = path.relative(execRoot, filePath);
        /** if it is under node_modules just allow file reads as we don't have a list of deps */
        if (!filePath.includes('node_modules') && !knownInputs.has(relative)) {
            throw new Error(`tsc tried to read file (${filePath}) that wasn't an input to it.`);
        }
        return ts.sys.readFile(filePath, encoding);
    }

    function directoryExists(directory) {
        if (!directory.startsWith(bin)) {
            return false;
        }
        const exists = ts.sys.directoryExists(directory);
        debuglog(`directoryExists ${directory} ${exists}`);
        return exists;
    }

    function getDirectories(directory) {
        const dirs = ts.sys.getDirectories(directory);
        debuglog(`getDirectories ${directory}`, dirs);
        return dirs;
    }

    function fileExists(filePath) {
        // TreeArtifact inputs are absent from input list so we have no way of knowing node_modules inputs.
        if (filePath.includes('node_modules')) {
            return ts.sys.fileExists(filePath)
        }
        const relative = path.relative(execRoot, filePath);
        debuglog(`fileExists ${filePath} ${knownInputs.has(relative)}`);
        return knownInputs.has(relative);
    }

    function readDirectory(directory, extensions, exclude, include, depth) {
        const files = ts.sys.readDirectory(directory, extensions, exclude, include, depth);

        if (directory.includes('node_modules')) {
            return files;
        }

        const strictView = [];

        for (const file of files) {
            const relativePath = path.relative(execRoot, file);
            if (knownInputs.has(relativePath)) {
                strictView.push(file);
            } else {
                debuglog(`Skipping ${relativePath} as it is not input to current compilation.`);
            }
        }

        debuglog(`readDirectory ${directory} ${strictView}`);

        return strictView;
    }

    function invalidate(filePath, kind) {
        if (filePath.endsWith('.params')) return;
        debuglog(`invalidate ${filePath} : ${ts.FileWatcherEventKind[kind]}`);

        if (kind === ts.FileWatcherEventKind.Created) {
            knownInputs.add(filePath);
        } else if (kind === ts.FileWatcherEventKind.Deleted) {
            knownInputs.delete(filePath);
        }

        const directoryWatcher = getDirectoryWatcherForPath(filePath)
        directoryWatcher?.(path.dirname(filePath));
        directoryWatcher?.(filePath);

        let callback = fileWatchers.get(filePath);

        callback?.(kind);
    }

    function watchDirectory(directoryPath, callback, recursive, options) {
        directoryPath = path.relative(execRoot, directoryPath);
        // since rules_js runs everything under bazel-out we shouldn't care about anything outside of it.
        if (!directoryPath.startsWith('bazel-out')) {
            return { close: () => {} };
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
                debuglog(`watchDirectory@close ${directoryPath}`);
            },
        };
    }

    function watchFile(filePath, callback, interval) {
        debuglog(`watchFile ${filePath} ${interval}`);
        const relativeFilePath = path.relative(execRoot, filePath);
        fileWatchers.set(relativeFilePath, (kind) => callback(filePath, kind));
        return {
            close: () => {
                fileWatchers.delete(relativeFilePath);
                debuglog(`watchFile@close ${filePath}`);
            },
        };
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
    const workir = getOrCreateWorker(args, Object.keys(inputs));

    const host = workir.host;
    const lastRequestTimestamp = Date.now();
    const previousInputs = workir.previousInputs;

    timingStart('checkAndApplyArgs');
    workir.checkAndApplyArgs(args);
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
                host.invalidate(input, ts.FileWatcherEventKind.Created);
            } else if (previousInputs[input] != digest) {
                host.invalidate(input, ts.FileWatcherEventKind.Changed);
            }
        }
        timingEnd('invalidate');
    }

    timingStart('applyChanges')
    host.applyChanges();
    timingEnd('applyChanges')

    timingStart('getProgram');
    const program = workir.program.getCurrentProgram()
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

    workir.previousInputs = inputs;

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

if (worker.runAsWorker(process.argv)) {
    worker.log(`Running ${MNEMONIC} as a Bazel worker`);
    worker.runWorkerLoop(emit);
} else {
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
