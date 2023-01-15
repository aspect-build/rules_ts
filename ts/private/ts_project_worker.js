const fs = require('fs');
const path = require('path');
const v8 = require('v8');
const ts = require('typescript');
const worker_protocol = require('./worker');
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

let VERBOSE = false;
function debug(...args) {
    VERBOSE && console.error(...args);
}

function setVerbosity(level) {
    // bazel set verbosity to 10 when --worker_verbose is set. 
    // See: https://bazel.build/remote/persistent#options
    VERBOSE = level > 0;
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

    function printTree() {
        const output = ["."]
        const walk = (node, prefix) => {
            const subnodes = Object.keys(node).sort();
            for (const [index, key] of subnodes.entries()) {
                const subnode = node[key];
                const parts = index == subnodes.length - 1 ? ["└── ", "    "] : ["├── ", "│   "];
                if (subnode[Type] == TYPE.SYMLINK) {
                    output.push(`${prefix}${parts[0]}${key} -> ${subnode[Symlink]}`);
                } else if (subnode[Type] == TYPE.FILE) {
                    output.push(`${prefix}${parts[0]}${key}`);
                } else {
                    output.push(`${prefix}${parts[0]}${key}`);
                    walk(subnode, `${prefix}${parts[1]}`);
                }
            }
        }
        walk(tree, "");
        debug(output.join("\n"))
    }

    function getNode(p) {
        const parts = p.split(path.sep);
        let node = tree;
        for (const part of parts) {
            if (!part) {
                continue;
            }
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
            const absoluteLinkPath = path.isAbsolute(linkpath) ? linkpath : path.resolve(path.dirname(absolutePath), linkpath)
            return path.relative(root, absoluteLinkPath);
        }
        return p;
    }

    function add(p) { 
        const parts = p.split(path.sep).filter(p => p != "");
        let node = tree;

        for (const [i, part] of parts.entries()) {
            if (node && node[Type] == TYPE.SYMLINK) {
                // stop; this is possibly path to a file which points to symlinked treeartifact.
                // bazel 6 has introduced a weird behavior where it expands treeartifact symlinks when --experimental_undeclared_symlink is turned off.
                return;
            }
            const currentP = parts.slice(0, i + 1).join(path.sep)   
            if (typeof node[part] != "object") {
                const possiblyResolvedSymlinkPath = followSymlinkUsingRealFs(currentP)
                if (possiblyResolvedSymlinkPath != currentP) {
                    node[part] = {
                        [Type]: TYPE.SYMLINK,
                        [Symlink]: possiblyResolvedSymlinkPath
                    }
                    notifyWatchers(parts.slice(0, i + 1), part, TYPE.SYMLINK, EVENT_TYPE.ADDED);
                    break;
                } 

                // last portion of the parts; which assumed to be a file
                if (i == parts.length-1) {
                    node[part] = { [Type]: TYPE.FILE };
                    notifyWatchers(parts.slice(0, i + 1), part, TYPE.FILE, EVENT_TYPE.ADDED);
                } else {
                    node[part] = { [Type]: TYPE.DIR };
                    notifyWatchers(parts.slice(0, i + 1), part, TYPE.DIR, EVENT_TYPE.ADDED);
                }
            }
            node = node[part];
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

    function notify(p) {
        const dirname = path.dirname(p);
        const basename = path.basename(p);
        notifyWatchers(dirname.split(path.sep), basename, TYPE.FILE, EVENT_TYPE.ADDED);
    }


    function fileExists(p) {
        const node = getNode(p);
        return typeof node == "object" && node[Type] == TYPE.FILE;
    }

    function directoryExists(p) {
        const node = getNode(p);
        return typeof node == "object" && node[Type] == TYPE.DIR;
    }

    function isSymlink(p) {
        const dirname = path.dirname(p);
        const basename = path.basename(p);
        const parentNode = getNode(dirname);
        if (!parentNode) {
            return false;
        }
        const node = parentNode[basename]
        return typeof node == "object" && node[Type] == TYPE.SYMLINK;
    }

    function realpath(p) {
        const parts = p.split(path.sep);
        let node = tree;
        let currentPath = "";
        for (const part of parts) {
            if (!part) {
                continue;
            }
            if (!(part in node)) {
                break;
            }
            node = node[part];
            currentPath = path.join(currentPath, part);
            if (node[Type] == TYPE.SYMLINK) {
                currentPath = node[Symlink];
                node = getNode(node[Symlink]);
                // Having dangling symlinks are commong outside of bazel but less likely using bazel unless 
                // a rule makes use of ctx.actions.declare_symlink and provide a path that may dangle.
                if (!node) {
                    break;
                }
            }
        }
        return path.isAbsolute(currentPath) ? currentPath : "/" + currentPath;
    }

    function readDirectory(p, extensions, exclude, include, depth) {
        const node = getNode(p);
        if (!node || node[Type] != TYPE.DIR) {
            return []
        }
        const result = [];
        let currentDepth = 0;
        const walk = (p, node) => {
            currentDepth++;
            for (const key in node) {
                const subp = path.join(p, key);
                const subnode = node[key];
                result.push(subp);
                if(subnode[Type] == TYPE.DIR) {
                    if (currentDepth >= depth || !depth) {
                        continue;
                    }
                    walk(subp, subnode);
                } else if (subnode[Type] == TYPE.SYMLINK) {
                    continue;
                }
            }
        }
        walk(p, node);
        return result;
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
            notifyWatcher(dest_parts, dest_parts, eventType);
            notifyWatcher(parts, dest_parts, eventType, null);
        } else {
            notifyWatcher(parts, dest_parts, eventType);
        }

        let recursive_parts = dest_parts;
        let fore_parts = [];
        while(recursive_parts.length) {
            fore_parts.unshift(recursive_parts.pop());
            notifyWatcher(recursive_parts, recursive_parts.concat(fore_parts), eventType, true);
        }
    }

    function notifyWatcher(parent, parts, eventType, recursive = false) {
        let node = getWatcherNode(parent);
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
            if (!part) {
                continue;
            } 
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

    return { add, remove, update, notify, fileExists, directoryExists, isSymlink, realpath, readDirectory, getDirectories, watchDirectory: watch, watchFile: watch, printTree }
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
            return libCache.get(fileName);
        }
        const sf = getSourceFile(fileName);
        if (sf && isExternalLib(fileName)) {
            debug(`createEmitAndLibCacheAndDiagnosticsProgram: putting default lib ${fileName} into cache.`)
            libCache.set(fileName, sf);
        }
        return sf;
    }

    return builder;
}

function createProgram(args, inputs, output) {
    const {options} = ts.parseCommandLine(args);
    const compilerOptions = {...options}

    compilerOptions.outDir = path.join("__synthetic__outdir__", compilerOptions.outDir);

    const bin = process.cwd();
    const execRoot = path.resolve(bin, '..', '..', '..');
    const tsconfig = path.relative(execRoot, path.resolve(bin, options.project));
    const cfg = path.relative(execRoot, bin)
    const executingFilePath = path.relative(execRoot , require.resolve("typescript"));

    const filesystemTree = createFilesystemTree(execRoot, inputs);
    const outputs = new Set();
    const watchEventQueue = new Array();

    /** @type {ts.System} */
    const strictSys = {
        write: write,
        writeOutputIsTTY: () => false,
        readFile: readFile,
        readDirectory: filesystemTree.readDirectory,
        createDirectory(p) {
            // TODO: cleanup
            debug("createDirectory", p);
            ts.sys.createDirectory(p.replace("__synthetic__outdir__", ".")); 
        },
        writeFile(p, data, mark) {
            // TODO: cleanup
            debug("writeFile", p);
            ts.sys.writeFile(p.replace("__synthetic__outdir__", "."), data, mark);
        },
        resolvePath: (p) => {},
        realpath: filesystemTree.realpath,
        fileExists: filesystemTree.fileExists,
        directoryExists: filesystemTree.directoryExists,
        getDirectories: filesystemTree.getDirectories,
        watchFile: watchFile,
        watchDirectory: watchDirectory,
        getCurrentDirectory: () => "/"+cfg,
        getExecutingFilePath: () => "/"+executingFilePath,
        exit: exit
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
    delete host.setTimeout;
    delete host.clearTimeout;


    /** @type {ts.FormatDiagnosticsHost} */
    const formatDiagnosticHost = {
        getCanonicalFileName: (path) => path,
        getCurrentDirectory: sys.getCurrentDirectory,
        getNewLine: () => sys.newLine,
    };

    debug(`tsconfig: ${tsconfig}`);
    debug(`execroot: ${execRoot}`);

    const program = ts.createWatchProgram(host);

    return { program, checkAndApplyArgs, enablePerformanceAndTracingIfNeeded, setOutput, formatDiagnostics, flushWatchEvents, invalidate, printFSTree: () => filesystemTree.printTree() };

    function formatDiagnostics(diagnostics) {
        return `\n${ts.formatDiagnostics(diagnostics, formatDiagnosticHost)}\n`
    }

    function setOutput(newOutput) {
        output = newOutput;
    }

    function write(chunk) {
        output.write(chunk);
    }

    function exit(exitCode) {
        debug(`program wanted to exit prematurely with code ${exitCode}`);
    }

    function flushWatchEvents() {
        for (const [callback, ...args] of watchEventQueue) {
            callback(...args);
        }
        watchEventQueue.length = 0;
    }

    function invalidate(filePath, kind) {
        if (filePath.endsWith('.params')) return;
        debug(`invalidate ${filePath} : ${ts.FileWatcherEventKind[kind]}`);
        if (kind === ts.FileWatcherEventKind.Deleted) {
            filesystemTree.remove(filePath);
        } else if (kind === ts.FileWatcherEventKind.Created) {
            filesystemTree.add(filePath);
        } else {
            filesystemTree.update(filePath);
        }
        if (filePath.indexOf("node_modules") != -1 && filesystemTree.isSymlink(filePath) && kind === ts.FileWatcherEventKind.Created) {
            const expandedInputs = filesystemTree.readDirectory(filePath, undefined, undefined, undefined, Infinity);
            for (const input of expandedInputs) {
                filesystemTree.notify(input);
            }
        }
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

    function readFile(filePath, encoding) {
        filePath = path.resolve(sys.getCurrentDirectory(), filePath)
        // external lib are transitive sources thus not listed in the inputs map reported by bazel.
        // if (!filesystemTree.fileExists(relative) && !isExternalLib(filePath) && !outputs.has(filePath)) {
        //     throw new Error(`tsc tried to read file (${filePath}) that wasn't an input to it.`);
        // }
        return ts.sys.readFile(path.join(execRoot, filePath), encoding);
    }

    function watchDirectory(directoryPath, callback, recursive, options) {
        const close = filesystemTree.watchDirectory(
            directoryPath,
            (input) => watchEventQueue.push([callback, path.join("/", input)]),
            recursive
        );

        return {close};
    }

    function watchFile(filePath, callback, _) {
        // ideally, all paths should be absolute but sometimes tsc passes relative ones.
        filePath = path.resolve(sys.getCurrentDirectory(), filePath)
        const close = filesystemTree.watchFile(
            filePath,
            (input, kind) => watchEventQueue.push([callback, path.join("/", input), kind])
        )
        return {close};
    }
}

function createCancellationToken(signal) {
    return {
        isCancellationRequested: () => signal.aborted,
        throwIfCancellationRequested: () => {
            if (signal.aborted) {
                throw new Error(signal.reason);
            }
        }
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
        debug(`garbage collection: removing ${k} to free memory.`);
        w.program.close();
        workers.delete(k);
        // stop killing workers as soon as the worker is out the oom zone 
        if (!isNearOomZone()) {
            debug(`garbage collection: finished`);
            break;
        }
    }
}

function getOrCreateWorker(args, inputs, output) {
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
        debug(`creating a new worker with the key ${key}`);
        worker = createProgram(args, inputs, output);
    } else {
        // NB: removed from the map intentionally. to achieve LRU effect on the workers map.
        workers.delete(key)
    }
    workers.set(key, worker)
    return worker;
}

/** Build */
async function emit(request) {
    setVerbosity(request.verbosity);
    debug(`# Beginning new work`);
    debug(`arguments: ${request.arguments.join(' ')}`)

    const inputs = Object.fromEntries(
        request.inputs.map(input => [
            input.path, 
            input.digest.byteLength ? Buffer.from(input.digest).toString("hex") : null
        ])
    );

    const worker = getOrCreateWorker(request.arguments, inputs, process.stderr);
    const previousInputs = worker.previousInputs;
    const cancellationToken = createCancellationToken(request.signal);

    timingStart('checkAndApplyArgs');
    worker.checkAndApplyArgs(request.arguments);
    timingEnd('checkAndApplyArgs');

    timingStart('enablePerformanceAndTracingIfNeeded');
    worker.enablePerformanceAndTracingIfNeeded();
    timingEnd('enablePerformanceAndTracingIfNeeded');


    if (previousInputs) {
        const changes = new Set(), creations = new Set();
        
        // worker.setOutput(request.output);

        timingStart(`invalidate`);
        for (const [input, digest] of Object.entries(inputs)) {
            if (!(input in previousInputs)) {
                creations.add(input);
            } else if (previousInputs[input] != digest) {
                changes.add(input);
            } else if (previousInputs[input] == null && digest == null) {
                // Assume symlinks always change. bazel <= 5.3 will always report symlinks without a digest.
                // therefore there is no way to determine if a symlink has changed. 
                changes.add(input);
            }
        }
        for (const input in previousInputs) {
            if (!(input in inputs)) {
                worker.invalidate(input, ts.FileWatcherEventKind.Deleted);
            }
        }
        for (const input of creations) {
            worker.invalidate(input, ts.FileWatcherEventKind.Created);
        }
        for (const input of changes) {
            worker.invalidate(input, ts.FileWatcherEventKind.Changed);
        }
        timingEnd('invalidate');

        timingStart('flushWatchEvents');
        worker.flushWatchEvents();
        timingEnd('flushWatchEvents');
    }

    timingStart('getProgram');
    const program = worker.program.getProgram();
    timingEnd('getProgram');

    timingStart('emit');
    const result = program.emit(undefined, undefined, cancellationToken);
    timingEnd('emit');

    timingStart('diagnostics');
    const diagnostics = ts.getPreEmitDiagnostics(program, undefined, cancellationToken).concat(result?.diagnostics);
    timingEnd('diagnostics');

    const succeded = !result.emitSkipped && result?.diagnostics.length === 0 && diagnostics.length === 0;

    if (!succeded) {
        request.output.write(worker.formatDiagnostics(diagnostics));
        VERBOSE && worker.printFSTree()
    }

    worker.previousInputs = inputs;

    if (ts.performance.isEnabled()) {
        ts.performance.forEachMeasure((name, duration) => request.output.write(`${name} time: ${duration}\n`));
        // Disabling performance will reset counters for the next compilation
        ts.performance.disable()
    }

    if (ts.tracing) {
        ts.tracing.stopTracing()
    }
    debug(`# Finished the work`);
    return succeded ? 0 : 1;
}

// Based on https://github.com/microsoft/TypeScript/blob/3fd8a6e44341f14681aa9d303dc380020ccb2147/src/executeCommandLine/executeCommandLine.ts#L465
function emitOnce(args) {
    const currentDirectory = ts.sys.getCurrentDirectory();
    const reportDiagnostic = ts.createDiagnosticReporter(ts.sys);
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
        console.error(formatDiagnostics(diagnostics));
    }

    return succeded;
}

if (require.main === module && worker_protocol.isPersistentWorker(process.argv)) {
    console.error(`Running ${MNEMONIC} as a Bazel worker`);
    console.error(`TypeScript version: ${ts.version}`);
    worker_protocol.enterWorkerLoop(emit);
} else if (require.main === module) {
    console.error(`WARNING: Running ${MNEMONIC} as a standalone process`);
    console.error(
        `Started a standalone process to perform this action but this might lead to some unexpected behavior with tsc due to being run non-sandboxed.`
    );
    console.error(
        `Your build might be misconfigured, try putting "build --strategy=${MNEMONIC}=worker" into your .bazelrc or add "supports_workers = False" attribute into this ts_project target.`
    );
    const args = getArgsFromParamFile();
    if (!emitOnce(args)) {
        process.exit(1);
    }
}

module.exports.__do_not_use_test_only__ = {createFilesystemTree: createFilesystemTree, emit: emit, workers: workers};
