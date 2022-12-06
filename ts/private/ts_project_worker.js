const fs = require('fs');
const path = require('path');
const v8 = require('v8');
const ts = require('typescript');
const worker = require('@bazel/worker');


// workaround for the issue introduced in https://github.com/microsoft/TypeScript/pull/42095
if (Array.isArray(ts.ignoredPaths)) {
    ts.ignoredPaths = ts.ignoredPaths.filter(ignoredPath => ignoredPath != "/node_modules/.")
}


/** Constants */
const MNEMONIC = 'TsProject';

/** Utils */
function noop() {}

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

/** Performance */
function timingStart(label) {
    ts.performance.mark(`before${label}`);
}
function timingEnd(label) {
    ts.performance.mark(`after${label}`);
    ts.performance.measure(`${MNEMONIC} ${label}`, `before${label}`, `after${label}`);
}


/** Virtual FS */
function createFilesystemTree(root, inputs) {
    const tree = {};
    const watchingTree = {};

    const TYPE = {
        DIR: 1,
        FILE: 2,
        SYMLINK: 3
    }

    const EVENT_TYPE = {
        ADDED: 0,
        UPDATED: 1,
        REMOVED: 2,
    }

    const Type = Symbol.for("fileSystemTree#type");
    const Symlink = Symbol.for("fileSystemTree#symlink");
    const Watcher = Symbol.for("fileSystemTree#watcher");

    for (const p in inputs) {
        add(p, inputs[p]);
    }

    function getNode(p) {
        const parts = p.split(path.sep);
        let node = tree;
        for (const part of parts) {
            if (!(part in node)) {
                return undefined;
            }
            node = node[part];
            if (node[Type] == TYPE.SYMLINK) {
                node = getNode(node[Symlink]);
                // Having dangling symlinks are commong outside of bazel but less likely using bazel 
                // unless a rule makes use of ctx.actions.declare_symlink and provide a path that may
                // dangle.
                if (!node) {
                    return undefined;
                }
            }
        }
        return node;
    }

    function followSymlinkUsingRealFs(p) {
        const absolutePath = path.join(root, p)
        const stat = fs.lstatSync(absolutePath)
        // bazel does not expose any information on whether an input is a REGULAR FILE,DIR or SYMLINK
        // therefore a real filesystem call has to be made for each input to determine the symlinks.
        // NOTE: making a readlink call is more expensive than making a lstat call
        if (stat.isSymbolicLink()) {
            const linkpath = fs.readlinkSync(absolutePath);
            const absoluteLinkPath = path.isAbsolute(linkpath) ? linkpath : path.resolve(path.dirname(absolutePath, linkpath))
            return path.relative(root, absoluteLinkPath);
        }
        return p;
    }

    function add(p) {
        const parts = path.parse(p);        
        const dirs = parts.dir.split(path.sep).filter(p => p != "");

        let node = tree;

        for (const [i, part] of dirs.entries()) {
            if (typeof node[part] != "object") {
                node[part] = {
                    [Type]: TYPE.DIR 
                };
                notifyWatchers(dirs.slice(0, i), part, TYPE.DIR, EVENT_TYPE.ADDED);
            }
            node = node[part];
        }

        const possiblyResolvedSymlinkPath = followSymlinkUsingRealFs(p)

        if (possiblyResolvedSymlinkPath != p) {
            node[parts.base] = {
                [Type]: TYPE.SYMLINK,
                [Symlink]: possiblyResolvedSymlinkPath
            }
            notifyWatchers(dirs, parts.base, TYPE.SYMLINK, EVENT_TYPE.ADDED);
        } else if (parts.base) {
            node[parts.base] = {
                [Type]: TYPE.FILE,
            };
            notifyWatchers(dirs, parts.base, TYPE.FILE, EVENT_TYPE.ADDED);
        }
    }

    function remove(p) {
        const parts = p.split(path.sep);
        let track = {parent: undefined, part: undefined, node: tree};
        for (const part of parts) {
            let node = track.node[part];
            if (!node) {
                // It is not likely to end up here unless fstree does something undesired. 
                // So we'll let it hard fail 
                throw new Error(`Could not find ${p}`);
            }
            track = {parent: track, segment: part, node: node }
        }

        delete track.parent.node[track.segment];
        notifyWatchers(parts.slice(0, - 1), track.segment, track.node[Type], EVENT_TYPE.REMOVED)

        let removal = track.parent;
        let removal_parts = parts.slice(0, -1)
        while(removal.parent) {
            if (Object.keys(removal.node).length == 0) {
                if (removal.node[Type] == TYPE.DIR) {
                    delete removal.parent.node[removal.segment];
                    notifyWatchers(removal_parts.slice(0, -1), removal.segment, TYPE.DIR, EVENT_TYPE.REMOVED)
                }
                removal = removal.parent;
                removal_parts.pop();
            } else {
                break;
            }
        }
    }

    function update(p) {
        const dirname = path.dirname(p);
        const basename = path.basename(p);
        // reason the node manipulated using the parent node is that the last node might be a symlink and `getNode` follows symlinks automatically.
        // ideally a new followSymlinks option could be introduced to `getNode` but that would prevent following the grand parents.
        // luckily, bazel does not allow complex symlinks structures such as symlink within symlink allowing this function to be dumb.
        const parentNode = getNode(dirname);
        const node = parentNode[basename];
        if (node[Type] == TYPE.SYMLINK) {
            const newSymlinkPath = followSymlinkUsingRealFs(p);
            if (newSymlinkPath == p /* Not a symlink anymore */) {
                node[Type] = TYPE.FILE;
                delete node[Symlink];
            } else if (node[Symlink] != newSymlinkPath) {
                node[Symlink] = newSymlinkPath;
            }
        }
        notifyWatchers(dirname.split(path.sep), basename, node[Type], EVENT_TYPE.UPDATED);
    }

    function fileExists(p) {
        const node = getNode(p);
        return typeof node == "object" && node[Type] == TYPE.FILE;
    }

    function directoryExists(p) {
        const node = getNode(p);
        return typeof node == "object" && node[Type] == TYPE.DIR;
    }

    function readDirectory(p, extensions, exclude, include, depth) {
        const node = getNode(p);
        if (!node || node[Type] != TYPE.DIR) {
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
        for (const part in node) {
            let subnode = node[part];

            if (subnode[Type] == TYPE.SYMLINK) {
                // get the node where the symlink points to
                subnode = getNode(subnode[Symlink]);
            }

            if (subnode[Type] == TYPE.DIR) {
                dirs.push(part);
            }
        }
        return dirs
    }

    function notifyWatchers(parts, part, type, eventType) {
        const dest_parts = [...parts, part];
        if (type == TYPE.FILE) {
            notifyWatcher(parts, dest_parts, eventType);
        } else {
            notifyWatcher(parts, dest_parts, eventType);
        }
        notifyWatcher(dest_parts, dest_parts, eventType, null);

        let recursive_parts = dest_parts;
        let fore_parts = [];
        while(recursive_parts.length) {
            fore_parts.unshift(recursive_parts.pop());
            notifyWatcher(recursive_parts, recursive_parts.concat(fore_parts), eventType, true);
        }
    }

    function notifyWatcher(parent, parts, eventType, recursive = false) {
        let node = getWatcherNode(parent, watchingTree);
        if (typeof node == "object" && Watcher in node) {
            for (const watcher of node[Watcher]) {
                if (recursive != null && watcher.recursive != recursive) {
                    continue;
                }
                watcher.callback(parts.join(path.sep), eventType);
            }
        }
    }

    function getWatcherNode(parts) {
        let node = watchingTree;
        for (const part of parts) {
            if (!(part in node)) {
                return undefined;
            }
            node = node[part];
        }
        return node;
    }

    function watch(p, callback, recursive = false) {
        const parts = p.split(path.sep);
        let node = watchingTree;
        for (const part of parts) {
            if (!(part in node)) {
                node[part] = {};
            }
            node = node[part];
        }
        if (!(Watcher in node)) {
            node[Watcher] = new Set();
        }  
        const watcher = {callback, recursive};
        node[Watcher].add(watcher);
        return () => node[Watcher].delete(watcher)
    }

    return { add, remove, update, fileExists, directoryExists, readDirectory, getDirectories, watchDirectory: watch, watchFile: watch }
}


/** Program and Caching */
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
    const NOT_FROM_SOURCE = Symbol.for("NOT_FROM_SOURCE")
    /** @type {Map<string, string>} */
    const outputSourceMapping = (host.outputSourceMapping = host.outputSourceMapping || new Map());
    /** @type {Map<string, {text: string, writeByteOrderMark: boolean}>} */
    const outputCache = (host.outputCache = host.outputCache || new Map());

    const emit = builder.emit;
    builder.emit = (targetSourceFile, writeFile, cancellationToken, emitOnlyDtsFiles, customTransformers) => {
        writeFile = writeFile || host.writeFile;
        if (!targetSourceFile) {
            for (const [path, entry] of outputCache.entries()) {
                const sourcePath = outputSourceMapping.get(path);
                // if the source is not part of the program anymore, then drop the output from the output cache.
                if (sourcePath != NOT_FROM_SOURCE && !builder.getSourceFile(sourcePath)) {
                    outputSourceMapping.delete(path);
                    outputCache.delete(path);
                    continue;
                } 
                writeFile(path, entry.text, entry.writeByteOrderMark);
            }
        }

        const writeF = (fileName, text, writeByteOrderMark, onError, sourceFiles) => {
            writeFile(fileName, text, writeByteOrderMark, onError, sourceFiles);
            outputCache.set(fileName, {text, writeByteOrderMark});
            if (sourceFiles?.length > 0) {
                outputSourceMapping.set(fileName, sourceFiles[0].fileName)
            } else {
                // if the file write is not the result of a source mark it as not from source not avoid cache drops.
                outputSourceMapping.set(fileName, NOT_FROM_SOURCE)
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

function createProgram(args, initialInputs) {
    const {options} = ts.parseCommandLine(args);
    const compilerOptions = {...options}

    const bin = process.cwd();
    const execRoot = path.resolve(bin, '..', '..', '..');
    const tsconfig = path.relative(execRoot, path.resolve(bin, options.project));

    const filesystemTree = createFilesystemTree(execRoot, initialInputs);
    const outputs = new Set();

    const taskQueue = new Array();

    /** @type {ts.System} */
    const strictSys = {
        write: (s) => process.stderr.write(s),
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

    return { host, program, checkAndApplyArgs, enablePerformanceAndTracingIfNeeded };

    function setTimeout(cb) {
        // NB: tsc will never clearTimeout if the index is 0 hence timeout must be truthy. :|
        // https://github.com/microsoft/TypeScript/blob/d0bfd8caed521bfd24fc44960d9936a891744bb7/src/compiler/watchPublic.ts#L681
        return taskQueue.push(cb);
    }
 
    function clearTimeout(i) {
        delete taskQueue[i - 1];
    }

    function applyChanges() {
        for (let i = 0; i < taskQueue.length; i++) {
            const task = taskQueue[i];
            delete taskQueue[i]
            if (task) {
                task();
            }  
        }
        taskQueue.length = 0;
    }

    function enablePerformanceAndTracingIfNeeded() {
        if (compilerOptions.extendedDiagnostics) {
            ts.performance.enable();
        }
        // tracing is only available in 4.1 and above
        // See: https://github.com/microsoft/TypeScript/wiki/Performance-Tracing
        if (compilerOptions.generateTrace && ts.startTracing && !ts.tracing) {
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
            filesystemTree.update(tsconfig);
            args = newArgs;
        }
    }

    function debuglog(message) {
        // TODO: https://github.com/aspect-build/rules_ts/issues/189
        compilerOptions.extendedDiagnostics && host.trace?.(message)
    }

    function readFile(filePath, encoding) {
        const relative = path.relative(execRoot, filePath);
        // external lib are transitive sources thus not listed in the inputs map reported by bazel.
        if (!filesystemTree.fileExists(path.relative(execRoot, filePath)) && !isExternalLib(filePath) && !outputs.has(relative)) {
            throw new Error(`tsc tried to read file (${filePath}) that wasn't an input to it.`);
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

    function invalidate(filePath, kind) {
        if (filePath.endsWith('.params')) return;
        debuglog(`invalidate ${filePath} : ${ts.FileWatcherEventKind[kind]}`);

        if (kind === ts.FileWatcherEventKind.Created) {
            filesystemTree.add(filePath);
        } else if (kind === ts.FileWatcherEventKind.Deleted) {
            filesystemTree.remove(filePath);
        } else {
            filesystemTree.update(filePath);
        }
    }

    function watchDirectory(directoryPath, callback, recursive, options) {
        // since rules_js runs everything under bazel-out we shouldn't care about anything outside of it.
        if (!directoryPath.startsWith(execRoot)) {
            return { close: noop };
        }
        const close = filesystemTree.watchDirectory(
            path.relative(execRoot, directoryPath),
            (input) => callback(path.join(execRoot, input)),
            recursive
        );

        return {close};
    }

    function watchFile(filePath, callback, interval) {
        if (!path.isAbsolute(filePath)) {
            filePath = path.resolve(filePath);
        }
        if (!filePath.startsWith(execRoot)) {
            return { close: noop };
        }
        const close = filesystemTree.watchFile(
            path.relative(execRoot, filePath),
            (input, kind) => callback(path.join(execRoot, input), kind)
        )
        return {close};
    }
}

/** Worker lifecycle */
const NEAR_OOM_ZONE = 20 // How much (%) of memory should be free at all times. 

function isNearOomZone() {
    const stat = v8.getHeapStatistics();
    const used = (100 / stat.heap_size_limit) * stat.used_heap_size
    return 100 - used < NEAR_OOM_ZONE
}

/** @type {Map<string, ReturnType<createProgram> & {previousInputs?: import("@bazel/worker").Inputs}>} */
const workers = new Map();

function sweepLeastRecentlyUsedWorkers() {
    for (const [k, w] of workers) {
        w.program.close();
        workers.delete(k);
        // stop killing workers as soon as the worker is out the oom zone 
        if (!isNearOomZone()) {
            break;
        }
    }
}

function getOrCreateWorker(args, inputs) {
    if (isNearOomZone()) {
        sweepLeastRecentlyUsedWorkers();
    }
    const project = args[args.indexOf('--project') + 1]
    const outDir = args[args.lastIndexOf("--outDir") + 1]
    const declarationDir = args[args.lastIndexOf("--declarationDir") + 1]
    const rootDir = args[args.lastIndexOf("--rootDir") + 1]
    const key = `${project} @ ${outDir} @ ${declarationDir} @ ${rootDir}`

    let worker = workers.get(key)
    if (!worker) {
        worker = createProgram(args, inputs);
        worker.host.debuglog(`Created a new worker for ${key}`);
    } else {
        // NB: removed from the map intentionally. to achieve LRU effect on the workers map.
        workers.delete(key)
    }
    workers.set(key, worker)
    return worker;
}

/** Build */
function emit(args, inputs) {
    const _worker = getOrCreateWorker(args, inputs);

    const host = _worker.host;
    const lastRequestTimestamp = Date.now();
    const previousInputs = _worker.previousInputs;

    timingStart('checkAndApplyArgs');
    _worker.checkAndApplyArgs(args);
    timingEnd('checkAndApplyArgs');

    timingStart('enablePerformanceAndTracingIfNeeded');
    _worker.enablePerformanceAndTracingIfNeeded();
    timingEnd('enablePerformanceAndTracingIfNeeded');

    const changes = new Set(), creations = new Set();

    if (previousInputs) {
        timingStart(`invalidate`);
        for (const [input, digest] of Object.entries(inputs)) {
            if (!(input in previousInputs)) {
                creations.add(input);
            } else if (previousInputs[input] != digest) {
                changes.add(input);
            }
        }
        for (const input in previousInputs) {
            if (!(input in inputs)) {
                host.invalidate(input, ts.FileWatcherEventKind.Deleted);
            }
        }
        for (const input of creations) {
            host.invalidate(input, ts.FileWatcherEventKind.Created);
        }
        for (const input of changes) {
            host.invalidate(input, ts.FileWatcherEventKind.Changed);
        }
        timingEnd('invalidate');
    }

    timingStart('applyChanges');
    host.applyChanges();
    if (creations.size) {
        timingStart('applyChanges for changes');
        for (const input of creations) {
            host.invalidate(input, ts.FileWatcherEventKind.Changed);
        }
        host.applyChanges();
        timingEnd('applyChanges for changes');
    }
    timingEnd('applyChanges');

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

module.exports.__do_not_use_test_only__ = {createFilesystemTree: createFilesystemTree, emit: emit, workers: workers};
