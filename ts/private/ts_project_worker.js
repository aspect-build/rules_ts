'use strict';

var path = require('node:path');
var v8 = require('v8');
var ts$1 = require('typescript');
var fs = require('node:fs');

function _interopNamespaceDefault(e) {
    var n = Object.create(null);
    if (e) {
        Object.keys(e).forEach(function (k) {
            if (k !== 'default') {
                var d = Object.getOwnPropertyDescriptor(e, k);
                Object.defineProperty(n, k, d.get ? d : {
                    enumerable: true,
                    get: function () { return e[k]; }
                });
            }
        });
    }
    n.default = e;
    return Object.freeze(n);
}

var path__namespace = /*#__PURE__*/_interopNamespaceDefault(path);
var v8__namespace = /*#__PURE__*/_interopNamespaceDefault(v8);
var ts__namespace = /*#__PURE__*/_interopNamespaceDefault(ts$1);
var fs__namespace = /*#__PURE__*/_interopNamespaceDefault(fs);

let VERBOSE = false;
function debug(...args) {
    VERBOSE && console.error(...args);
}
function setVerbosity(level) {
    // bazel set verbosity to 10 when --worker_verbose is set. 
    // See: https://bazel.build/remote/persistent#options
    VERBOSE = level > 0;
}
function isVerbose() {
    return VERBOSE;
}

function notImplemented(name, _throw, _returnArg) {
    return (...args) => {
        if (_throw) {
            throw new Error(`function ${name} is not implemented.`);
        }
        debug(`function ${name} is not implemented.`);
        return args[_returnArg];
    };
}
function noop(..._) { }

const TypeSymbol = Symbol.for("fileSystemTree#type");
const SymlinkSymbol = Symbol.for("fileSystemTree#symlink");
const WatcherSymbol = Symbol.for("fileSystemTree#watcher");
function createFilesystemTree(root, inputs) {
    const tree = {};
    const watchingTree = {};
    for (const p in inputs) {
        add(p);
    }
    function printTree() {
        const output = ["."];
        const walk = (node, prefix) => {
            const subnodes = Object.keys(node).sort((a, b) => node[a][TypeSymbol] - node[b][TypeSymbol]);
            for (const [index, key] of subnodes.entries()) {
                const subnode = node[key];
                const parts = index == subnodes.length - 1 ? ["└── ", "    "] : ["├── ", "│   "];
                if (subnode[TypeSymbol] == 3 /* Type.SYMLINK */) {
                    output.push(`${prefix}${parts[0]}${key} -> ${subnode[SymlinkSymbol]}`);
                }
                else if (subnode[TypeSymbol] == 2 /* Type.FILE */) {
                    output.push(`${prefix}${parts[0]}<file> ${key}`);
                }
                else {
                    output.push(`${prefix}${parts[0]}<dir> ${key}`);
                    walk(subnode, `${prefix}${parts[1]}`);
                }
            }
        };
        walk(tree, "");
        debug(output.join("\n"));
    }
    function getNode(p) {
        const segments = p.split(path__namespace.sep);
        let node = tree;
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            if (!(segment in node)) {
                return undefined;
            }
            node = node[segment];
            if (node[TypeSymbol] == 3 /* Type.SYMLINK */) {
                node = getNode(node[SymlinkSymbol]);
                // dangling symlink; symlinks point to a non-existing path.
                if (!node) {
                    return undefined;
                }
            }
        }
        return node;
    }
    function followSymlinkUsingRealFs(p) {
        const absolutePath = path__namespace.join(root, p);
        const stat = fs__namespace.lstatSync(absolutePath);
        // bazel does not expose any information on whether an input is a REGULAR FILE,DIR or SYMLINK
        // therefore a real filesystem call has to be made for each input to determine the symlinks.
        // NOTE: making a readlink call is more expensive than making a lstat call
        if (stat.isSymbolicLink()) {
            const linkpath = fs__namespace.readlinkSync(absolutePath);
            const absoluteLinkPath = path__namespace.isAbsolute(linkpath) ? linkpath : path__namespace.resolve(path__namespace.dirname(absolutePath), linkpath);
            return path__namespace.relative(root, absoluteLinkPath);
        }
        return p;
    }
    function add(p) {
        const segments = p.split(path__namespace.sep);
        const parents = [];
        let node = tree;
        for (let i = 0; i < segments.length; i++) {
            const segment = segments[i];
            if (node && node[TypeSymbol] == 3 /* Type.SYMLINK */) {
                // stop; this is possibly path to a symlink which points to a treeartifact.
                //// version 6.0.0 has a weird behavior where it expands symlinks that point to treeartifact when --experimental_allow_unresolved_symlinks is turned off.
                debug(`WEIRD_BAZEL_6_BEHAVIOR: stopping at ${parents.join(path__namespace.sep)}`);
                return;
            }
            const currentp = path__namespace.join(...parents, segment);
            if (typeof node[segment] != "object") {
                const possiblyResolvedSymlinkPath = followSymlinkUsingRealFs(currentp);
                if (possiblyResolvedSymlinkPath != currentp) {
                    node[segment] = {
                        [TypeSymbol]: 3 /* Type.SYMLINK */,
                        [SymlinkSymbol]: possiblyResolvedSymlinkPath
                    };
                    notifyWatchers(parents, segment, 3 /* Type.SYMLINK */, 0 /* EventType.ADDED */);
                    return;
                }
                // last of the segments; which assumed to be a file
                if (i == segments.length - 1) {
                    node[segment] = { [TypeSymbol]: 2 /* Type.FILE */ };
                    notifyWatchers(parents, segment, 2 /* Type.FILE */, 0 /* EventType.ADDED */);
                }
                else {
                    node[segment] = { [TypeSymbol]: 1 /* Type.DIR */ };
                    notifyWatchers(parents, segment, 1 /* Type.DIR */, 0 /* EventType.ADDED */);
                }
            }
            node = node[segment];
            parents.push(segment);
        }
    }
    function remove(p) {
        const segments = p.split(path__namespace.sep).filter(seg => seg != "");
        let node = {
            parent: undefined,
            segment: undefined,
            current: tree
        };
        for (let i = 0; i < segments.length; i++) {
            const segment = segments[i];
            if (node.current[TypeSymbol] == 3 /* Type.SYMLINK */) {
                debug(`WEIRD_BAZEL_6_BEHAVIOR: removing ${p} starting from the symlink parent since it's a node with a parent that is a symlink.`);
                segments.splice(i); // remove rest of the elements starting from i which comes right after symlink segment.
                break;
            }
            const current = node.current[segment];
            if (!current) {
                // It is not likely to end up here unless fstree does something undesired. 
                // we will soft fail here due to regression in bazel 6.0
                debug(`remove: could not find ${p}`);
                return;
            }
            node = {
                parent: node,
                segment: segment,
                current: current
            };
        }
        // parent path of current path(p)
        const parentSegments = segments.slice(0, -1);
        // remove current node using parent node
        delete node.parent.current[node.segment];
        notifyWatchers(parentSegments, node.segment, node.current[TypeSymbol], 2 /* EventType.REMOVED */);
        // start traversing from parent of last segment
        let removal = node.parent;
        let parents = [...parentSegments];
        while (removal.parent) {
            const keys = Object.keys(removal.current);
            if (keys.length > 0) {
                // if current node has subnodes, DIR, FILE, SYMLINK etc, then stop traversing up as we reached a parent node that has subnodes. 
                break;
            }
            // walk one segment up/parent to avoid calling slice for notifyWatchers. 
            parents.pop();
            if (removal.current[TypeSymbol] == 1 /* Type.DIR */) {
                // current node has no children. remove current node using its parent node
                delete removal.parent.current[removal.segment];
                notifyWatchers(parents, removal.segment, 1 /* Type.DIR */, 2 /* EventType.REMOVED */);
            }
            // traverse up
            removal = removal.parent;
        }
    }
    function update(p) {
        const segments = p.split(path__namespace.sep);
        const parent = [];
        let node = tree;
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            parent.push(segment);
            const currentp = parent.join(path__namespace.sep);
            if (!node[segment]) {
                debug(`WEIRD_BAZEL_6_BEHAVIOR: can't walk down the path ${p} from ${currentp} inside ${segment}`);
                // bazel 6 + --noexperimental_allow_unresolved_symlinks: has a weird behavior where bazel will won't report symlink changes but 
                // rather reports changes in the treeartifact that symlink points to. even if symlink points to somewhere new. :(
                // since `remove` removed this node previously,  we just need to call add to create necessary nodes.
                // see: no_unresolved_symlink_tests.bats for test cases
                return add(p);
            }
            node = node[segment];
            if (node[TypeSymbol] == 3 /* Type.SYMLINK */) {
                const newSymlinkPath = followSymlinkUsingRealFs(currentp);
                if (newSymlinkPath == currentp) {
                    // not a symlink anymore.
                    debug(`${currentp} is no longer a symlink since ${currentp} == ${newSymlinkPath}`);
                    node[TypeSymbol] = 2 /* Type.FILE */;
                    delete node[SymlinkSymbol];
                }
                else if (node[SymlinkSymbol] != newSymlinkPath) {
                    debug(`updating symlink ${currentp} from ${node[SymlinkSymbol]} to ${newSymlinkPath}`);
                    node[SymlinkSymbol] = newSymlinkPath;
                }
                notifyWatchers(parent, segment, node[TypeSymbol], 1 /* EventType.UPDATED */);
                return; // return the loop as we don't anything to be symlinks from on;
            }
        }
        // did not encounter any symlinks along the way. it's a DIR or FILE at this point.
        const basename = parent.pop();
        notifyWatchers(parent, basename, node[TypeSymbol], 1 /* EventType.UPDATED */);
    }
    function notify(p) {
        const dirname = path__namespace.dirname(p);
        const basename = path__namespace.basename(p);
        notifyWatchers(dirname.split(path__namespace.sep), basename, 2 /* Type.FILE */, 0 /* EventType.ADDED */);
    }
    function fileExists(p) {
        const node = getNode(p);
        return typeof node == "object" && node[TypeSymbol] == 2 /* Type.FILE */;
    }
    function directoryExists(p) {
        const node = getNode(p);
        return typeof node == "object" && node[TypeSymbol] == 1 /* Type.DIR */;
    }
    function normalizeIfSymlink(p) {
        const segments = p.split(path__namespace.sep);
        let node = tree;
        let parents = [];
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            if (!(segment in node)) {
                break;
            }
            node = node[segment];
            parents.push(segment);
            if (node[TypeSymbol] == 3 /* Type.SYMLINK */) {
                // ideally this condition would not met until the last segment of the path unless there's a symlink segment in
                // earlier segments. this indeed happens in bazel 6.0 with --experimental_allow_unresolved_symlinks turned off.
                break;
            }
        }
        if (typeof node == "object" && node[TypeSymbol] == 3 /* Type.SYMLINK */) {
            return parents.join(path__namespace.sep);
        }
        return undefined;
    }
    function realpath(p) {
        const segments = p.split(path__namespace.sep);
        let node = tree;
        let currentPath = "";
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            if (!(segment in node)) {
                break;
            }
            node = node[segment];
            currentPath = path__namespace.join(currentPath, segment);
            if (node[TypeSymbol] == 3 /* Type.SYMLINK */) {
                currentPath = node[SymlinkSymbol];
                node = getNode(node[SymlinkSymbol]);
                // dangling symlink; symlinks point to a non-existing path. can't follow it
                if (!node) {
                    break;
                }
            }
        }
        return path__namespace.isAbsolute(currentPath) ? currentPath : "/" + currentPath;
    }
    function readDirectory(p, extensions, exclude, include, depth) {
        const node = getNode(p);
        if (!node || node[TypeSymbol] != 1 /* Type.DIR */) {
            return [];
        }
        const result = [];
        let currentDepth = 0;
        const walk = (p, node) => {
            currentDepth++;
            for (const key in node) {
                const subp = path__namespace.join(p, key);
                const subnode = node[key];
                result.push(subp);
                if (subnode[TypeSymbol] == 1 /* Type.DIR */) {
                    if (currentDepth >= depth || !depth) {
                        continue;
                    }
                    walk(subp, subnode);
                }
                else if (subnode[TypeSymbol] == 3 /* Type.SYMLINK */) {
                    continue;
                }
            }
        };
        walk(p, node);
        return result;
    }
    function getDirectories(p) {
        const node = getNode(p);
        if (!node) {
            return [];
        }
        const dirs = [];
        for (const part in node) {
            let subnode = node[part];
            if (subnode[TypeSymbol] == 3 /* Type.SYMLINK */) {
                // get the node where the symlink points to
                subnode = getNode(subnode[SymlinkSymbol]);
            }
            if (subnode[TypeSymbol] == 1 /* Type.DIR */) {
                dirs.push(part);
            }
        }
        return dirs;
    }
    function notifyWatchers(trail, segment, type, eventType) {
        const final = [...trail, segment];
        const finalPath = final.join(path__namespace.sep);
        if (type == 2 /* Type.FILE */) {
            // notify file watchers watching at the file path, excluding recursive ones. 
            notifyWatcher(final, finalPath, eventType, /* recursive */ false);
            // notify directory watchers watching at the parent of the file, including the recursive directory watchers at parent.
            notifyWatcher(trail, finalPath, eventType);
        }
        else {
            // notify directory watchers watching at the parent of the directory, including recursive ones.
            notifyWatcher(trail, finalPath, eventType);
        }
        // recursively invoke watchers starting from trail;
        //  given path `/path/to/something/else`
        // this loop will call watchers all at `segment` with combination of these arguments;
        //  parent = /path/to/something     path = /path/to/something/else
        //  parent = /path/to               path = /path/to/something/else
        //  parent = /path                  path = /path/to/something/else
        let parent = [...trail];
        while (parent.length) {
            parent.pop();
            // invoke only recursive watchers
            notifyWatcher(parent, finalPath, eventType, true);
        }
    }
    function notifyWatcher(parent, path, eventType, recursive) {
        let node = getWatcherNode(parent);
        if (typeof node == "object" && WatcherSymbol in node) {
            for (const watcher of node[WatcherSymbol]) {
                // if recursive argument isn't provided, invoke both recursive and non-recursive watchers.
                if (recursive != undefined && watcher.recursive != recursive) {
                    continue;
                }
                watcher.callback(path, eventType);
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
        const parts = p.split(path__namespace.sep);
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
        if (!(WatcherSymbol in node)) {
            node[WatcherSymbol] = new Set();
        }
        const watcher = { callback, recursive };
        node[WatcherSymbol].add(watcher);
        return () => node[WatcherSymbol].delete(watcher);
    }
    function watchFile(p, callback) {
        return watch(p, callback);
    }
    return { add, remove, update, notify, fileExists, directoryExists, normalizeIfSymlink, realpath, readDirectory, getDirectories, watchDirectory: watch, watchFile: watchFile, printTree };
}

const workers = new Map();
const libCache = new Map();
const NOT_FROM_SOURCE = Symbol.for("NOT_FROM_SOURCE");
const NEAR_OOM_ZONE = 20; // How much (%) of memory should be free at all times. 
const SYNTHETIC_OUTDIR = "__st_outdir__";
function isNearOomZone() {
    const stat = v8__namespace.getHeapStatistics();
    const used = (100 / stat.heap_size_limit) * stat.used_heap_size;
    return 100 - used < NEAR_OOM_ZONE;
}
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
    const project = args[args.indexOf('--project') + 1];
    const outDir = args[args.lastIndexOf("--outDir") + 1];
    const declarationDir = args[args.lastIndexOf("--declarationDir") + 1];
    const rootDir = args[args.lastIndexOf("--rootDir") + 1];
    const key = `${project} @ ${outDir} @ ${declarationDir} @ ${rootDir}`;
    let worker = workers.get(key);
    if (!worker) {
        debug(`creating a new worker with the key ${key}`);
        worker = createProgram(args, inputs, output, (exitCode) => {
            debug(`worker ${key} has quit prematurely with code ${exitCode}`);
            workers.delete(key);
        });
    }
    else {
        // NB: removed from the map intentionally. to achieve LRU effect on the workers map.
        workers.delete(key);
    }
    workers.set(key, worker);
    return worker;
}
function testOnlyGetWorkers() {
    return workers;
}
function isExternalLib(path) {
    return path.includes('external') &&
        path.includes('typescript@') &&
        path.includes('node_modules/typescript/lib');
}
function createEmitAndLibCacheAndDiagnosticsProgram(rootNames, options, host, oldProgram, configFileParsingDiagnostics, projectReferences) {
    const builder = ts__namespace.createEmitAndSemanticDiagnosticsBuilderProgram(rootNames, options, host, oldProgram, configFileParsingDiagnostics, projectReferences);
    /** Emit Cache */
    const outputSourceMapping = (host["outputSourceMapping"] = host["outputSourceMapping"] || new Map());
    /** @type {Map<string, {text: string, writeByteOrderMark: boolean}>} */
    const outputCache = (host["outputCache"] = host["outputCache"] || new Map());
    const emit = builder.emit;
    builder.emit = (targetSourceFile, writeFile, cancellationToken, emitOnlyDtsFiles, customTransformers) => {
        const write = writeFile || host.writeFile;
        if (!targetSourceFile) {
            for (const [path, entry] of outputCache.entries()) {
                const sourcePath = outputSourceMapping.get(path);
                if (sourcePath == NOT_FROM_SOURCE) {
                    write(path, entry.text, entry.writeByteOrderMark);
                    continue;
                }
                // it a file that has to ties to a source file
                if (sourcePath == NOT_FROM_SOURCE) {
                    continue;
                }
                else if (!builder.getSourceFile(sourcePath)) {
                    // source is not part of the program anymore, so drop the output from the output cache.
                    debug(`createEmitAndLibCacheAndDiagnosticsProgram: deleting ${sourcePath} as it's no longer a src.`);
                    outputSourceMapping.delete(path);
                    outputCache.delete(path);
                    continue;
                }
            }
        }
        const writeF = (fileName, text, writeByteOrderMark, onError, sourceFiles) => {
            write(fileName, text, writeByteOrderMark, onError, sourceFiles);
            outputCache.set(fileName, { text, writeByteOrderMark });
            if (sourceFiles?.length && sourceFiles?.length > 0) {
                outputSourceMapping.set(fileName, sourceFiles[0].fileName);
            }
            else {
                // if the file write is not the result of a source mark it as not from source not avoid cache drops.
                outputSourceMapping.set(fileName, NOT_FROM_SOURCE);
            }
        };
        return emit(targetSourceFile, writeF, cancellationToken, emitOnlyDtsFiles, customTransformers);
    };
    /** Lib Cache */
    const getSourceFile = host.getSourceFile;
    host.getSourceFile = (fileName, languageVersionOrOptions, onError, shouldCreateNewSourceFile) => {
        if (libCache.has(fileName)) {
            return libCache.get(fileName);
        }
        const sf = getSourceFile(fileName, languageVersionOrOptions, onError, shouldCreateNewSourceFile);
        if (sf && isExternalLib(fileName)) {
            debug(`createEmitAndLibCacheAndDiagnosticsProgram: putting default lib ${fileName} into cache.`);
            libCache.set(fileName, sf);
        }
        return sf;
    };
    return builder;
}
function createProgram(args, inputs, output, exit) {
    const cmd = ts__namespace.parseCommandLine(args);
    const bin = process.cwd(); // <execroot>/bazel-bin/<cfg>/bin
    const execroot = path__namespace.resolve(bin, '..', '..', '..'); // execroot
    const tsconfig = path__namespace.relative(execroot, path__namespace.resolve(bin, cmd.options.project)); // bazel-bin/<cfg>/bin/<pkg>/<options.project>
    const cfg = path__namespace.relative(execroot, bin); // /bazel-bin/<cfg>/bin
    const executingfilepath = path__namespace.relative(execroot, require.resolve("typescript")); // /bazel-bin/<opt-cfg>/bin/node_modules/tsc/...
    const filesystem = createFilesystemTree(execroot, inputs);
    const outputs = new Set();
    const watchEventQueue = new Array();
    const watchEventsForSymlinks = new Set();
    const strictSys = {
        write: write,
        writeOutputIsTTY: () => false,
        getCurrentDirectory: () => "/" + cfg,
        getExecutingFilePath: () => "/" + executingfilepath,
        exit: exit,
        resolvePath: notImplemented("sys.resolvePath", true, 0),
        // handled by fstree.
        realpath: filesystem.realpath,
        fileExists: filesystem.fileExists,
        directoryExists: filesystem.directoryExists,
        getDirectories: filesystem.getDirectories,
        readFile: readFile,
        readDirectory: filesystem.readDirectory,
        createDirectory: createDirectory,
        writeFile: writeFile,
        watchFile: watchFile,
        watchDirectory: watchDirectory
    };
    const sys = { ...ts__namespace.sys, ...strictSys };
    const host = ts__namespace.createWatchCompilerHost(cmd.options.project, cmd.options, sys, createEmitAndLibCacheAndDiagnosticsProgram, noop, noop);
    // deleting this will make tsc to not schedule updates but wait for getProgram to be called to apply updates which is exactly what is needed.
    delete host.setTimeout;
    delete host.clearTimeout;
    const formatDiagnosticHost = {
        getCanonicalFileName: (path) => path,
        getCurrentDirectory: sys.getCurrentDirectory,
        getNewLine: () => sys.newLine,
    };
    debug(`tsconfig: ${tsconfig}`);
    debug(`execroot: ${execroot}`);
    debug(`bin: ${bin}`);
    debug(`cfg: ${cfg}`);
    debug(`executingfilepath: ${executingfilepath}`);
    let compilerOptions = readCompilerOptions();
    enableStatisticsAndTracing();
    updateOutputs();
    applySyntheticOutPaths();
    const program = ts__namespace.createWatchProgram(host);
    // early return to prevent from declaring more variables accidentially. 
    return { program, applyArgs, setOutput, formatDiagnostics, flushWatchEvents, invalidate, postRun, printFSTree: filesystem.printTree };
    function formatDiagnostics(diagnostics) {
        return `\n${ts__namespace.formatDiagnostics(diagnostics, formatDiagnosticHost)}\n`;
    }
    function setOutput(newOutput) {
        output = newOutput;
    }
    function write(chunk) {
        output.write(chunk);
    }
    function enqueueAdditionalWatchEventsForSymlinks() {
        for (const symlink of watchEventsForSymlinks) {
            const expandedInputs = filesystem.readDirectory(symlink, undefined, undefined, undefined, Infinity);
            for (const input of expandedInputs) {
                filesystem.notify(input);
            }
        }
        watchEventsForSymlinks.clear();
    }
    function flushWatchEvents() {
        enqueueAdditionalWatchEventsForSymlinks();
        for (const [callback, ...args] of watchEventQueue) {
            callback(...args);
        }
        watchEventQueue.length = 0;
    }
    function invalidate(filePath, kind) {
        debug(`invalidate ${filePath} : ${ts__namespace.FileWatcherEventKind[kind]}`);
        if (kind === ts__namespace.FileWatcherEventKind.Changed && filePath == tsconfig) {
            applyChangesForTsConfig(args);
        }
        if (kind === ts__namespace.FileWatcherEventKind.Deleted) {
            filesystem.remove(filePath);
        }
        else if (kind === ts__namespace.FileWatcherEventKind.Created) {
            filesystem.add(filePath);
        }
        else {
            filesystem.update(filePath);
        }
        if (filePath.indexOf("node_modules") != -1 && kind === ts__namespace.FileWatcherEventKind.Created) {
            const normalizedFilePath = filesystem.normalizeIfSymlink(filePath);
            if (normalizedFilePath) {
                watchEventsForSymlinks.add(normalizedFilePath);
            }
        }
    }
    function enableStatisticsAndTracing() {
        if (compilerOptions.diagnostics || compilerOptions.extendedDiagnostics || host.optionsToExtend.diagnostics || host.optionsToExtend.extendedDiagnostics) {
            ts__namespace["performance"].enable();
        }
        // tracing is only available in 4.1 and above
        // See: https://github.com/microsoft/TypeScript/wiki/Performance-Tracing
        if ((compilerOptions.generateTrace || host.optionsToExtend.generateTrace) && ts__namespace["startTracing"] && !ts__namespace["tracing"]) {
            ts__namespace["startTracing"]('build', compilerOptions.generateTrace || host.optionsToExtend.generateTrace);
        }
    }
    function disableStatisticsAndTracing() {
        ts__namespace["performance"].disable();
        if (ts__namespace["tracing"]) {
            ts__namespace["tracing"].stopTracing();
        }
    }
    function postRun() {
        if (ts__namespace["performance"] && ts__namespace["performance"].isEnabled()) {
            ts__namespace["performance"].disable();
            ts__namespace["performance"].enable();
        }
        if (ts__namespace["tracing"]) {
            ts__namespace["tracing"].stopTracing();
        }
    }
    function updateOutputs() {
        outputs.clear();
        if (host.optionsToExtend.tsBuildInfoFile || compilerOptions.tsBuildInfoFile) {
            const p = path__namespace.join(sys.getCurrentDirectory(), host.optionsToExtend.tsBuildInfoFile);
            outputs.add(p);
        }
    }
    function applySyntheticOutPaths() {
        host.optionsToExtend.outDir = `${host.optionsToExtend.outDir}/${SYNTHETIC_OUTDIR}`;
        if (host.optionsToExtend.declarationDir) {
            host.optionsToExtend.declarationDir = `${host.optionsToExtend.declarationDir}/${SYNTHETIC_OUTDIR}`;
        }
    }
    function applyArgs(newArgs) {
        // This function works based on the assumption that parseConfigFile of createWatchProgram will always read optionsToExtend by reference.
        // See: https://github.com/microsoft/TypeScript/blob/2ecde2718722d6643773d43390aa57c3e3199365/src/compiler/watchPublic.ts#L735
        // and: https://github.com/microsoft/TypeScript/blob/2ecde2718722d6643773d43390aa57c3e3199365/src/compiler/watchPublic.ts#L296
        if (args.join(' ') != newArgs.join(' ')) {
            debug(`arguments have changed.`);
            debug(`  current: ${newArgs.join(" ")}`);
            debug(`  previous: ${args.join(" ")}`);
            applyChangesForTsConfig(args);
            // invalidating tsconfig will cause parseConfigFile to be invoked
            filesystem.update(tsconfig);
            args = newArgs;
        }
    }
    function readCompilerOptions() {
        const raw = ts__namespace.readConfigFile(cmd.options.project, readFile);
        const parsedCommandLine = ts__namespace.parseJsonConfigFileContent(raw.config, sys, path__namespace.dirname(cmd.options.project));
        return parsedCommandLine.options || {};
    }
    function applyChangesForTsConfig(args) {
        const cmd = ts__namespace.parseCommandLine(args);
        for (const key in host.optionsToExtend) {
            delete host.optionsToExtend[key];
        }
        for (const key in cmd.options) {
            host.optionsToExtend[key] = cmd.options[key];
        }
        compilerOptions = readCompilerOptions();
        disableStatisticsAndTracing();
        enableStatisticsAndTracing();
        updateOutputs();
        applySyntheticOutPaths();
    }
    function readFile(filePath, encoding) {
        filePath = path__namespace.resolve(sys.getCurrentDirectory(), filePath);
        //external lib are transitive sources thus not listed in the inputs map reported by bazel.
        if (!filesystem.fileExists(filePath) && !isExternalLib(filePath) && !outputs.has(filePath)) {
            output.write(`tsc tried to read file (${filePath}) that wasn't an input to it.` + "\n");
            throw new Error(`tsc tried to read file (${filePath}) that wasn't an input to it.`);
        }
        return ts__namespace.sys.readFile(path__namespace.join(execroot, filePath), encoding);
    }
    function createDirectory(p) {
        p = p.replace(SYNTHETIC_OUTDIR, "");
        ts__namespace.sys.createDirectory(p);
    }
    function writeFile(p, data, writeByteOrderMark) {
        p = p.replace(SYNTHETIC_OUTDIR, "");
        if (p.endsWith(".map")) {
            // We need to postprocess map files to fix paths for the sources. This is required because we have a SYNTHETIC_OUTDIR suffix and 
            // tsc tries to relativitize sources back to rootDir. in order to fix it the leading `../` needed to be stripped out.
            // We tried a few options to make tsc do this for us.
            // 
            // 1- Using mapRoot to reroot map files. This didn't work because either path in `sourceMappingUrl` or path in `sources` was incorrect.
            // 
            // 2- Using a converging parent path for `outDir` and `rootDir` so tsc reroots sourcemaps to that directory. This didn't work either because
            // eventhough the converging parent path looked correct in a subpackage, it was incorrect at the root directory because `../` pointed to out 
            // of output tree.
            // 
            // This left us with post-processing the `.map` files so that paths looks correct.
            const sourceGroup = data.match(/"sources":\[.*?]/).at(0);
            const fixedSourceGroup = sourceGroup.replace(/"..\//g, `"`);
            data = data.replace(sourceGroup, fixedSourceGroup);
        }
        ts__namespace.sys.writeFile(p, data, writeByteOrderMark);
    }
    function watchDirectory(directoryPath, callback, recursive, options) {
        const close = filesystem.watchDirectory(directoryPath, (input) => watchEventQueue.push([callback, path__namespace.join("/", input)]), recursive);
        return { close };
    }
    function watchFile(filePath, callback, pollingInterval, options) {
        // ideally, all paths should be absolute but sometimes tsc passes relative ones.
        filePath = path__namespace.resolve(sys.getCurrentDirectory(), filePath);
        const close = filesystem.watchFile(filePath, (input, kind) => watchEventQueue.push([callback, path__namespace.join("/", input), kind]));
        return { close };
    }
}

const ts = require('typescript');
// workaround for the issue introduced in https://github.com/microsoft/TypeScript/pull/42095
if (Array.isArray(ts["ignoredPaths"])) {
    ts["ignoredPaths"] = ts["ignoredPaths"].filter(ignoredPath => ignoredPath != "/node_modules/.");
}

const worker_protocol = require('./worker');
const MNEMONIC = 'TsProject';
function timingStart(label) {
    // @ts-expect-error
    ts__namespace.performance.mark(`before${label}`);
}
function timingEnd(label) {
    // @ts-expect-error
    ts__namespace.performance.mark(`after${label}`);
    // @ts-expect-error
    ts__namespace.performance.measure(`${MNEMONIC} ${label}`, `before${label}`, `after${label}`);
}
function createCancellationToken(signal) {
    return {
        isCancellationRequested: () => signal.aborted,
        throwIfCancellationRequested: () => {
            if (signal.aborted) {
                throw new Error(signal.reason);
            }
        }
    };
}
/** Build */
async function emit(request) {
    setVerbosity(request.verbosity);
    debug(`# Beginning new work`);
    debug(`arguments: ${request.arguments.join(' ')}`);
    const inputs = Object.fromEntries(request.inputs.map((input) => [
        input.path,
        input.digest.byteLength ? Buffer.from(input.digest).toString("hex") : null
    ]));
    const worker = getOrCreateWorker(request.arguments, inputs, process.stderr);
    const cancellationToken = createCancellationToken(request.signal);
    if (worker.previousInputs) {
        const previousInputs = worker.previousInputs;
        timingStart('applyArgs');
        worker.applyArgs(request.arguments);
        timingEnd('applyArgs');
        const changes = new Set(), creations = new Set();
        timingStart(`invalidate`);
        for (const [input, digest] of Object.entries(inputs)) {
            if (!(input in previousInputs)) {
                creations.add(input);
            }
            else if (previousInputs[input] != digest) {
                changes.add(input);
            }
            else if (previousInputs[input] == null && digest == null) {
                // Assume symlinks always change. bazel <= 5.3 will always report symlinks without a digest.
                // therefore there is no way to determine if a symlink has changed. 
                changes.add(input);
            }
        }
        for (const input in previousInputs) {
            if (!(input in inputs)) {
                worker.invalidate(input, ts__namespace.FileWatcherEventKind.Deleted);
            }
        }
        for (const input of creations) {
            worker.invalidate(input, ts__namespace.FileWatcherEventKind.Created);
        }
        for (const input of changes) {
            worker.invalidate(input, ts__namespace.FileWatcherEventKind.Changed);
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
    const diagnostics = ts__namespace.getPreEmitDiagnostics(program, undefined, cancellationToken).concat(result?.diagnostics);
    timingEnd('diagnostics');
    const succeded = diagnostics.length === 0;
    if (!succeded) {
        request.output.write(worker.formatDiagnostics(diagnostics));
        isVerbose() && worker.printFSTree();
    }
    // @ts-expect-error
    if (ts__namespace.performance && ts__namespace.performance.isEnabled()) {
        // @ts-expect-error
        ts__namespace.performance.forEachMeasure((name, duration) => request.output.write(`${name} time: ${duration}\n`));
    }
    worker.previousInputs = inputs;
    worker.postRun();
    debug(`# Finished the work`);
    return succeded ? 0 : 1;
}
if (require.main === module && worker_protocol.isPersistentWorker(process.argv)) {
    console.error(`Running ${MNEMONIC} as a Bazel worker`);
    console.error(`TypeScript version: ${ts__namespace.version}`);
    worker_protocol.enterWorkerLoop(emit);
}
else if (require.main === module) {
    if (!process.cwd().includes("sandbox")) {
        console.error(`WARNING: Running ${MNEMONIC} as a standalone process`);
        console.error(`Started a standalone process to perform this action but this might lead to some unexpected behavior with tsc due to being run non-sandboxed.`);
        console.error(`Your build might be misconfigured, try putting "build --strategy=${MNEMONIC}=worker" into your .bazelrc or add "supports_workers = False" attribute into this ts_project target.`);
    }
    function executeCommandLine() {
        // will execute tsc.
        require("typescript/lib/tsc");
    }
    // newer versions of typescript exposes executeCommandLine function we will prefer to use. 
    // if it's missing, due to older version of typescript, we'll use our implementation which calls tsc.js by requiring it.
    // @ts-expect-error
    const execute = ts__namespace.executeCommandLine || executeCommandLine;
    let p = process.argv[process.argv.length - 1];
    if (p.startsWith('@')) {
        // p is relative to execroot but we are in bazel-out so we have to go three times up to reach execroot.
        // p = bazel-out/darwin_arm64-fastbuild/bin/0.params
        // currentDir =  bazel-out/darwin_arm64-fastbuild/bin
        p = path__namespace.resolve('..', '..', '..', p.slice(1));
    }
    const args = fs__namespace.readFileSync(p).toString().trim().split('\n');
    ts__namespace.sys.args = process.argv = [process.argv0, process.argv[1], ...args];
    execute(ts__namespace.sys, noop, args);
}
const __do_not_use_test_only__ = { createFilesystemTree: createFilesystemTree, emit: emit, workers: testOnlyGetWorkers() };

exports.__do_not_use_test_only__ = __do_not_use_test_only__;
//# sourceMappingURL=data:application/json;charset=utf-8;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiYnVuZGxlLmpzIiwic291cmNlcyI6WyJkZWJ1Z2dpbmcuanMiLCJ1dGlsLmpzIiwidmZzLmpzIiwicHJvZ3JhbS5qcyIsInBhdGNoZXMuanMiLCJlbnRyeXBvaW50LmpzIl0sInNvdXJjZXNDb250ZW50IjpbImxldCBWRVJCT1NFID0gZmFsc2U7XG5leHBvcnQgZnVuY3Rpb24gZGVidWcoLi4uYXJncykge1xuICAgIFZFUkJPU0UgJiYgY29uc29sZS5lcnJvciguLi5hcmdzKTtcbn1cbmV4cG9ydCBmdW5jdGlvbiBzZXRWZXJib3NpdHkobGV2ZWwpIHtcbiAgICAvLyBiYXplbCBzZXQgdmVyYm9zaXR5IHRvIDEwIHdoZW4gLS13b3JrZXJfdmVyYm9zZSBpcyBzZXQuIFxuICAgIC8vIFNlZTogaHR0cHM6Ly9iYXplbC5idWlsZC9yZW1vdGUvcGVyc2lzdGVudCNvcHRpb25zXG4gICAgVkVSQk9TRSA9IGxldmVsID4gMDtcbn1cbmV4cG9ydCBmdW5jdGlvbiBpc1ZlcmJvc2UoKSB7XG4gICAgcmV0dXJuIFZFUkJPU0U7XG59XG4vLyMgc291cmNlTWFwcGluZ1VSTD1kZWJ1Z2dpbmcuanMubWFwIiwiaW1wb3J0IHsgZGVidWcgfSBmcm9tIFwiLi9kZWJ1Z2dpbmdcIjtcbmV4cG9ydCBmdW5jdGlvbiBub3RJbXBsZW1lbnRlZChuYW1lLCBfdGhyb3csIF9yZXR1cm5BcmcpIHtcbiAgICByZXR1cm4gKC4uLmFyZ3MpID0+IHtcbiAgICAgICAgaWYgKF90aHJvdykge1xuICAgICAgICAgICAgdGhyb3cgbmV3IEVycm9yKGBmdW5jdGlvbiAke25hbWV9IGlzIG5vdCBpbXBsZW1lbnRlZC5gKTtcbiAgICAgICAgfVxuICAgICAgICBkZWJ1ZyhgZnVuY3Rpb24gJHtuYW1lfSBpcyBub3QgaW1wbGVtZW50ZWQuYCk7XG4gICAgICAgIHJldHVybiBhcmdzW19yZXR1cm5BcmddO1xuICAgIH07XG59XG5leHBvcnQgZnVuY3Rpb24gbm9vcCguLi5fKSB7IH1cbi8vIyBzb3VyY2VNYXBwaW5nVVJMPXV0aWwuanMubWFwIiwiaW1wb3J0ICogYXMgcGF0aCBmcm9tIFwibm9kZTpwYXRoXCI7XG5pbXBvcnQgKiBhcyBmcyBmcm9tIFwibm9kZTpmc1wiO1xuaW1wb3J0IHsgZGVidWcgfSBmcm9tIFwiLi9kZWJ1Z2dpbmdcIjtcbmNvbnN0IFR5cGVTeW1ib2wgPSBTeW1ib2wuZm9yKFwiZmlsZVN5c3RlbVRyZWUjdHlwZVwiKTtcbmNvbnN0IFN5bWxpbmtTeW1ib2wgPSBTeW1ib2wuZm9yKFwiZmlsZVN5c3RlbVRyZWUjc3ltbGlua1wiKTtcbmNvbnN0IFdhdGNoZXJTeW1ib2wgPSBTeW1ib2wuZm9yKFwiZmlsZVN5c3RlbVRyZWUjd2F0Y2hlclwiKTtcbmV4cG9ydCBmdW5jdGlvbiBjcmVhdGVGaWxlc3lzdGVtVHJlZShyb290LCBpbnB1dHMpIHtcbiAgICBjb25zdCB0cmVlID0ge307XG4gICAgY29uc3Qgd2F0Y2hpbmdUcmVlID0ge307XG4gICAgZm9yIChjb25zdCBwIGluIGlucHV0cykge1xuICAgICAgICBhZGQocCk7XG4gICAgfVxuICAgIGZ1bmN0aW9uIHByaW50VHJlZSgpIHtcbiAgICAgICAgY29uc3Qgb3V0cHV0ID0gW1wiLlwiXTtcbiAgICAgICAgY29uc3Qgd2FsayA9IChub2RlLCBwcmVmaXgpID0+IHtcbiAgICAgICAgICAgIGNvbnN0IHN1Ym5vZGVzID0gT2JqZWN0LmtleXMobm9kZSkuc29ydCgoYSwgYikgPT4gbm9kZVthXVtUeXBlU3ltYm9sXSAtIG5vZGVbYl1bVHlwZVN5bWJvbF0pO1xuICAgICAgICAgICAgZm9yIChjb25zdCBbaW5kZXgsIGtleV0gb2Ygc3Vibm9kZXMuZW50cmllcygpKSB7XG4gICAgICAgICAgICAgICAgY29uc3Qgc3Vibm9kZSA9IG5vZGVba2V5XTtcbiAgICAgICAgICAgICAgICBjb25zdCBwYXJ0cyA9IGluZGV4ID09IHN1Ym5vZGVzLmxlbmd0aCAtIDEgPyBbXCLilJTilIDilIAgXCIsIFwiICAgIFwiXSA6IFtcIuKUnOKUgOKUgCBcIiwgXCLilILCoMKgIFwiXTtcbiAgICAgICAgICAgICAgICBpZiAoc3Vibm9kZVtUeXBlU3ltYm9sXSA9PSAzIC8qIFR5cGUuU1lNTElOSyAqLykge1xuICAgICAgICAgICAgICAgICAgICBvdXRwdXQucHVzaChgJHtwcmVmaXh9JHtwYXJ0c1swXX0ke2tleX0gLT4gJHtzdWJub2RlW1N5bWxpbmtTeW1ib2xdfWApO1xuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgICBlbHNlIGlmIChzdWJub2RlW1R5cGVTeW1ib2xdID09IDIgLyogVHlwZS5GSUxFICovKSB7XG4gICAgICAgICAgICAgICAgICAgIG91dHB1dC5wdXNoKGAke3ByZWZpeH0ke3BhcnRzWzBdfTxmaWxlPiAke2tleX1gKTtcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgZWxzZSB7XG4gICAgICAgICAgICAgICAgICAgIG91dHB1dC5wdXNoKGAke3ByZWZpeH0ke3BhcnRzWzBdfTxkaXI+ICR7a2V5fWApO1xuICAgICAgICAgICAgICAgICAgICB3YWxrKHN1Ym5vZGUsIGAke3ByZWZpeH0ke3BhcnRzWzFdfWApO1xuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgIH1cbiAgICAgICAgfTtcbiAgICAgICAgd2Fsayh0cmVlLCBcIlwiKTtcbiAgICAgICAgZGVidWcob3V0cHV0LmpvaW4oXCJcXG5cIikpO1xuICAgIH1cbiAgICBmdW5jdGlvbiBnZXROb2RlKHApIHtcbiAgICAgICAgY29uc3Qgc2VnbWVudHMgPSBwLnNwbGl0KHBhdGguc2VwKTtcbiAgICAgICAgbGV0IG5vZGUgPSB0cmVlO1xuICAgICAgICBmb3IgKGNvbnN0IHNlZ21lbnQgb2Ygc2VnbWVudHMpIHtcbiAgICAgICAgICAgIGlmICghc2VnbWVudCkge1xuICAgICAgICAgICAgICAgIGNvbnRpbnVlO1xuICAgICAgICAgICAgfVxuICAgICAgICAgICAgaWYgKCEoc2VnbWVudCBpbiBub2RlKSkge1xuICAgICAgICAgICAgICAgIHJldHVybiB1bmRlZmluZWQ7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBub2RlID0gbm9kZVtzZWdtZW50XTtcbiAgICAgICAgICAgIGlmIChub2RlW1R5cGVTeW1ib2xdID09IDMgLyogVHlwZS5TWU1MSU5LICovKSB7XG4gICAgICAgICAgICAgICAgbm9kZSA9IGdldE5vZGUobm9kZVtTeW1saW5rU3ltYm9sXSk7XG4gICAgICAgICAgICAgICAgLy8gZGFuZ2xpbmcgc3ltbGluazsgc3ltbGlua3MgcG9pbnQgdG8gYSBub24tZXhpc3RpbmcgcGF0aC5cbiAgICAgICAgICAgICAgICBpZiAoIW5vZGUpIHtcbiAgICAgICAgICAgICAgICAgICAgcmV0dXJuIHVuZGVmaW5lZDtcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICAgICAgcmV0dXJuIG5vZGU7XG4gICAgfVxuICAgIGZ1bmN0aW9uIGZvbGxvd1N5bWxpbmtVc2luZ1JlYWxGcyhwKSB7XG4gICAgICAgIGNvbnN0IGFic29sdXRlUGF0aCA9IHBhdGguam9pbihyb290LCBwKTtcbiAgICAgICAgY29uc3Qgc3RhdCA9IGZzLmxzdGF0U3luYyhhYnNvbHV0ZVBhdGgpO1xuICAgICAgICAvLyBiYXplbCBkb2VzIG5vdCBleHBvc2UgYW55IGluZm9ybWF0aW9uIG9uIHdoZXRoZXIgYW4gaW5wdXQgaXMgYSBSRUdVTEFSIEZJTEUsRElSIG9yIFNZTUxJTktcbiAgICAgICAgLy8gdGhlcmVmb3JlIGEgcmVhbCBmaWxlc3lzdGVtIGNhbGwgaGFzIHRvIGJlIG1hZGUgZm9yIGVhY2ggaW5wdXQgdG8gZGV0ZXJtaW5lIHRoZSBzeW1saW5rcy5cbiAgICAgICAgLy8gTk9URTogbWFraW5nIGEgcmVhZGxpbmsgY2FsbCBpcyBtb3JlIGV4cGVuc2l2ZSB0aGFuIG1ha2luZyBhIGxzdGF0IGNhbGxcbiAgICAgICAgaWYgKHN0YXQuaXNTeW1ib2xpY0xpbmsoKSkge1xuICAgICAgICAgICAgY29uc3QgbGlua3BhdGggPSBmcy5yZWFkbGlua1N5bmMoYWJzb2x1dGVQYXRoKTtcbiAgICAgICAgICAgIGNvbnN0IGFic29sdXRlTGlua1BhdGggPSBwYXRoLmlzQWJzb2x1dGUobGlua3BhdGgpID8gbGlua3BhdGggOiBwYXRoLnJlc29sdmUocGF0aC5kaXJuYW1lKGFic29sdXRlUGF0aCksIGxpbmtwYXRoKTtcbiAgICAgICAgICAgIHJldHVybiBwYXRoLnJlbGF0aXZlKHJvb3QsIGFic29sdXRlTGlua1BhdGgpO1xuICAgICAgICB9XG4gICAgICAgIHJldHVybiBwO1xuICAgIH1cbiAgICBmdW5jdGlvbiBhZGQocCkge1xuICAgICAgICBjb25zdCBzZWdtZW50cyA9IHAuc3BsaXQocGF0aC5zZXApO1xuICAgICAgICBjb25zdCBwYXJlbnRzID0gW107XG4gICAgICAgIGxldCBub2RlID0gdHJlZTtcbiAgICAgICAgZm9yIChsZXQgaSA9IDA7IGkgPCBzZWdtZW50cy5sZW5ndGg7IGkrKykge1xuICAgICAgICAgICAgY29uc3Qgc2VnbWVudCA9IHNlZ21lbnRzW2ldO1xuICAgICAgICAgICAgaWYgKG5vZGUgJiYgbm9kZVtUeXBlU3ltYm9sXSA9PSAzIC8qIFR5cGUuU1lNTElOSyAqLykge1xuICAgICAgICAgICAgICAgIC8vIHN0b3A7IHRoaXMgaXMgcG9zc2libHkgcGF0aCB0byBhIHN5bWxpbmsgd2hpY2ggcG9pbnRzIHRvIGEgdHJlZWFydGlmYWN0LlxuICAgICAgICAgICAgICAgIC8vLy8gdmVyc2lvbiA2LjAuMCBoYXMgYSB3ZWlyZCBiZWhhdmlvciB3aGVyZSBpdCBleHBhbmRzIHN5bWxpbmtzIHRoYXQgcG9pbnQgdG8gdHJlZWFydGlmYWN0IHdoZW4gLS1leHBlcmltZW50YWxfYWxsb3dfdW5yZXNvbHZlZF9zeW1saW5rcyBpcyB0dXJuZWQgb2ZmLlxuICAgICAgICAgICAgICAgIGRlYnVnKGBXRUlSRF9CQVpFTF82X0JFSEFWSU9SOiBzdG9wcGluZyBhdCAke3BhcmVudHMuam9pbihwYXRoLnNlcCl9YCk7XG4gICAgICAgICAgICAgICAgcmV0dXJuO1xuICAgICAgICAgICAgfVxuICAgICAgICAgICAgY29uc3QgY3VycmVudHAgPSBwYXRoLmpvaW4oLi4ucGFyZW50cywgc2VnbWVudCk7XG4gICAgICAgICAgICBpZiAodHlwZW9mIG5vZGVbc2VnbWVudF0gIT0gXCJvYmplY3RcIikge1xuICAgICAgICAgICAgICAgIGNvbnN0IHBvc3NpYmx5UmVzb2x2ZWRTeW1saW5rUGF0aCA9IGZvbGxvd1N5bWxpbmtVc2luZ1JlYWxGcyhjdXJyZW50cCk7XG4gICAgICAgICAgICAgICAgaWYgKHBvc3NpYmx5UmVzb2x2ZWRTeW1saW5rUGF0aCAhPSBjdXJyZW50cCkge1xuICAgICAgICAgICAgICAgICAgICBub2RlW3NlZ21lbnRdID0ge1xuICAgICAgICAgICAgICAgICAgICAgICAgW1R5cGVTeW1ib2xdOiAzIC8qIFR5cGUuU1lNTElOSyAqLyxcbiAgICAgICAgICAgICAgICAgICAgICAgIFtTeW1saW5rU3ltYm9sXTogcG9zc2libHlSZXNvbHZlZFN5bWxpbmtQYXRoXG4gICAgICAgICAgICAgICAgICAgIH07XG4gICAgICAgICAgICAgICAgICAgIG5vdGlmeVdhdGNoZXJzKHBhcmVudHMsIHNlZ21lbnQsIDMgLyogVHlwZS5TWU1MSU5LICovLCAwIC8qIEV2ZW50VHlwZS5BRERFRCAqLyk7XG4gICAgICAgICAgICAgICAgICAgIHJldHVybjtcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgLy8gbGFzdCBvZiB0aGUgc2VnbWVudHM7IHdoaWNoIGFzc3VtZWQgdG8gYmUgYSBmaWxlXG4gICAgICAgICAgICAgICAgaWYgKGkgPT0gc2VnbWVudHMubGVuZ3RoIC0gMSkge1xuICAgICAgICAgICAgICAgICAgICBub2RlW3NlZ21lbnRdID0geyBbVHlwZVN5bWJvbF06IDIgLyogVHlwZS5GSUxFICovIH07XG4gICAgICAgICAgICAgICAgICAgIG5vdGlmeVdhdGNoZXJzKHBhcmVudHMsIHNlZ21lbnQsIDIgLyogVHlwZS5GSUxFICovLCAwIC8qIEV2ZW50VHlwZS5BRERFRCAqLyk7XG4gICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICAgIGVsc2Uge1xuICAgICAgICAgICAgICAgICAgICBub2RlW3NlZ21lbnRdID0geyBbVHlwZVN5bWJvbF06IDEgLyogVHlwZS5ESVIgKi8gfTtcbiAgICAgICAgICAgICAgICAgICAgbm90aWZ5V2F0Y2hlcnMocGFyZW50cywgc2VnbWVudCwgMSAvKiBUeXBlLkRJUiAqLywgMCAvKiBFdmVudFR5cGUuQURERUQgKi8pO1xuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIG5vZGUgPSBub2RlW3NlZ21lbnRdO1xuICAgICAgICAgICAgcGFyZW50cy5wdXNoKHNlZ21lbnQpO1xuICAgICAgICB9XG4gICAgfVxuICAgIGZ1bmN0aW9uIHJlbW92ZShwKSB7XG4gICAgICAgIGNvbnN0IHNlZ21lbnRzID0gcC5zcGxpdChwYXRoLnNlcCkuZmlsdGVyKHNlZyA9PiBzZWcgIT0gXCJcIik7XG4gICAgICAgIGxldCBub2RlID0ge1xuICAgICAgICAgICAgcGFyZW50OiB1bmRlZmluZWQsXG4gICAgICAgICAgICBzZWdtZW50OiB1bmRlZmluZWQsXG4gICAgICAgICAgICBjdXJyZW50OiB0cmVlXG4gICAgICAgIH07XG4gICAgICAgIGZvciAobGV0IGkgPSAwOyBpIDwgc2VnbWVudHMubGVuZ3RoOyBpKyspIHtcbiAgICAgICAgICAgIGNvbnN0IHNlZ21lbnQgPSBzZWdtZW50c1tpXTtcbiAgICAgICAgICAgIGlmIChub2RlLmN1cnJlbnRbVHlwZVN5bWJvbF0gPT0gMyAvKiBUeXBlLlNZTUxJTksgKi8pIHtcbiAgICAgICAgICAgICAgICBkZWJ1ZyhgV0VJUkRfQkFaRUxfNl9CRUhBVklPUjogcmVtb3ZpbmcgJHtwfSBzdGFydGluZyBmcm9tIHRoZSBzeW1saW5rIHBhcmVudCBzaW5jZSBpdCdzIGEgbm9kZSB3aXRoIGEgcGFyZW50IHRoYXQgaXMgYSBzeW1saW5rLmApO1xuICAgICAgICAgICAgICAgIHNlZ21lbnRzLnNwbGljZShpKTsgLy8gcmVtb3ZlIHJlc3Qgb2YgdGhlIGVsZW1lbnRzIHN0YXJ0aW5nIGZyb20gaSB3aGljaCBjb21lcyByaWdodCBhZnRlciBzeW1saW5rIHNlZ21lbnQuXG4gICAgICAgICAgICAgICAgYnJlYWs7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBjb25zdCBjdXJyZW50ID0gbm9kZS5jdXJyZW50W3NlZ21lbnRdO1xuICAgICAgICAgICAgaWYgKCFjdXJyZW50KSB7XG4gICAgICAgICAgICAgICAgLy8gSXQgaXMgbm90IGxpa2VseSB0byBlbmQgdXAgaGVyZSB1bmxlc3MgZnN0cmVlIGRvZXMgc29tZXRoaW5nIHVuZGVzaXJlZC4gXG4gICAgICAgICAgICAgICAgLy8gd2Ugd2lsbCBzb2Z0IGZhaWwgaGVyZSBkdWUgdG8gcmVncmVzc2lvbiBpbiBiYXplbCA2LjBcbiAgICAgICAgICAgICAgICBkZWJ1ZyhgcmVtb3ZlOiBjb3VsZCBub3QgZmluZCAke3B9YCk7XG4gICAgICAgICAgICAgICAgcmV0dXJuO1xuICAgICAgICAgICAgfVxuICAgICAgICAgICAgbm9kZSA9IHtcbiAgICAgICAgICAgICAgICBwYXJlbnQ6IG5vZGUsXG4gICAgICAgICAgICAgICAgc2VnbWVudDogc2VnbWVudCxcbiAgICAgICAgICAgICAgICBjdXJyZW50OiBjdXJyZW50XG4gICAgICAgICAgICB9O1xuICAgICAgICB9XG4gICAgICAgIC8vIHBhcmVudCBwYXRoIG9mIGN1cnJlbnQgcGF0aChwKVxuICAgICAgICBjb25zdCBwYXJlbnRTZWdtZW50cyA9IHNlZ21lbnRzLnNsaWNlKDAsIC0xKTtcbiAgICAgICAgLy8gcmVtb3ZlIGN1cnJlbnQgbm9kZSB1c2luZyBwYXJlbnQgbm9kZVxuICAgICAgICBkZWxldGUgbm9kZS5wYXJlbnQuY3VycmVudFtub2RlLnNlZ21lbnRdO1xuICAgICAgICBub3RpZnlXYXRjaGVycyhwYXJlbnRTZWdtZW50cywgbm9kZS5zZWdtZW50LCBub2RlLmN1cnJlbnRbVHlwZVN5bWJvbF0sIDIgLyogRXZlbnRUeXBlLlJFTU9WRUQgKi8pO1xuICAgICAgICAvLyBzdGFydCB0cmF2ZXJzaW5nIGZyb20gcGFyZW50IG9mIGxhc3Qgc2VnbWVudFxuICAgICAgICBsZXQgcmVtb3ZhbCA9IG5vZGUucGFyZW50O1xuICAgICAgICBsZXQgcGFyZW50cyA9IFsuLi5wYXJlbnRTZWdtZW50c107XG4gICAgICAgIHdoaWxlIChyZW1vdmFsLnBhcmVudCkge1xuICAgICAgICAgICAgY29uc3Qga2V5cyA9IE9iamVjdC5rZXlzKHJlbW92YWwuY3VycmVudCk7XG4gICAgICAgICAgICBpZiAoa2V5cy5sZW5ndGggPiAwKSB7XG4gICAgICAgICAgICAgICAgLy8gaWYgY3VycmVudCBub2RlIGhhcyBzdWJub2RlcywgRElSLCBGSUxFLCBTWU1MSU5LIGV0YywgdGhlbiBzdG9wIHRyYXZlcnNpbmcgdXAgYXMgd2UgcmVhY2hlZCBhIHBhcmVudCBub2RlIHRoYXQgaGFzIHN1Ym5vZGVzLiBcbiAgICAgICAgICAgICAgICBicmVhaztcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIC8vIHdhbGsgb25lIHNlZ21lbnQgdXAvcGFyZW50IHRvIGF2b2lkIGNhbGxpbmcgc2xpY2UgZm9yIG5vdGlmeVdhdGNoZXJzLiBcbiAgICAgICAgICAgIHBhcmVudHMucG9wKCk7XG4gICAgICAgICAgICBpZiAocmVtb3ZhbC5jdXJyZW50W1R5cGVTeW1ib2xdID09IDEgLyogVHlwZS5ESVIgKi8pIHtcbiAgICAgICAgICAgICAgICAvLyBjdXJyZW50IG5vZGUgaGFzIG5vIGNoaWxkcmVuLiByZW1vdmUgY3VycmVudCBub2RlIHVzaW5nIGl0cyBwYXJlbnQgbm9kZVxuICAgICAgICAgICAgICAgIGRlbGV0ZSByZW1vdmFsLnBhcmVudC5jdXJyZW50W3JlbW92YWwuc2VnbWVudF07XG4gICAgICAgICAgICAgICAgbm90aWZ5V2F0Y2hlcnMocGFyZW50cywgcmVtb3ZhbC5zZWdtZW50LCAxIC8qIFR5cGUuRElSICovLCAyIC8qIEV2ZW50VHlwZS5SRU1PVkVEICovKTtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIC8vIHRyYXZlcnNlIHVwXG4gICAgICAgICAgICByZW1vdmFsID0gcmVtb3ZhbC5wYXJlbnQ7XG4gICAgICAgIH1cbiAgICB9XG4gICAgZnVuY3Rpb24gdXBkYXRlKHApIHtcbiAgICAgICAgY29uc3Qgc2VnbWVudHMgPSBwLnNwbGl0KHBhdGguc2VwKTtcbiAgICAgICAgY29uc3QgcGFyZW50ID0gW107XG4gICAgICAgIGxldCBub2RlID0gdHJlZTtcbiAgICAgICAgZm9yIChjb25zdCBzZWdtZW50IG9mIHNlZ21lbnRzKSB7XG4gICAgICAgICAgICBpZiAoIXNlZ21lbnQpIHtcbiAgICAgICAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIHBhcmVudC5wdXNoKHNlZ21lbnQpO1xuICAgICAgICAgICAgY29uc3QgY3VycmVudHAgPSBwYXJlbnQuam9pbihwYXRoLnNlcCk7XG4gICAgICAgICAgICBpZiAoIW5vZGVbc2VnbWVudF0pIHtcbiAgICAgICAgICAgICAgICBkZWJ1ZyhgV0VJUkRfQkFaRUxfNl9CRUhBVklPUjogY2FuJ3Qgd2FsayBkb3duIHRoZSBwYXRoICR7cH0gZnJvbSAke2N1cnJlbnRwfSBpbnNpZGUgJHtzZWdtZW50fWApO1xuICAgICAgICAgICAgICAgIC8vIGJhemVsIDYgKyAtLW5vZXhwZXJpbWVudGFsX2FsbG93X3VucmVzb2x2ZWRfc3ltbGlua3M6IGhhcyBhIHdlaXJkIGJlaGF2aW9yIHdoZXJlIGJhemVsIHdpbGwgd29uJ3QgcmVwb3J0IHN5bWxpbmsgY2hhbmdlcyBidXQgXG4gICAgICAgICAgICAgICAgLy8gcmF0aGVyIHJlcG9ydHMgY2hhbmdlcyBpbiB0aGUgdHJlZWFydGlmYWN0IHRoYXQgc3ltbGluayBwb2ludHMgdG8uIGV2ZW4gaWYgc3ltbGluayBwb2ludHMgdG8gc29tZXdoZXJlIG5ldy4gOihcbiAgICAgICAgICAgICAgICAvLyBzaW5jZSBgcmVtb3ZlYCByZW1vdmVkIHRoaXMgbm9kZSBwcmV2aW91c2x5LCAgd2UganVzdCBuZWVkIHRvIGNhbGwgYWRkIHRvIGNyZWF0ZSBuZWNlc3Nhcnkgbm9kZXMuXG4gICAgICAgICAgICAgICAgLy8gc2VlOiBub191bnJlc29sdmVkX3N5bWxpbmtfdGVzdHMuYmF0cyBmb3IgdGVzdCBjYXNlc1xuICAgICAgICAgICAgICAgIHJldHVybiBhZGQocCk7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBub2RlID0gbm9kZVtzZWdtZW50XTtcbiAgICAgICAgICAgIGlmIChub2RlW1R5cGVTeW1ib2xdID09IDMgLyogVHlwZS5TWU1MSU5LICovKSB7XG4gICAgICAgICAgICAgICAgY29uc3QgbmV3U3ltbGlua1BhdGggPSBmb2xsb3dTeW1saW5rVXNpbmdSZWFsRnMoY3VycmVudHApO1xuICAgICAgICAgICAgICAgIGlmIChuZXdTeW1saW5rUGF0aCA9PSBjdXJyZW50cCkge1xuICAgICAgICAgICAgICAgICAgICAvLyBub3QgYSBzeW1saW5rIGFueW1vcmUuXG4gICAgICAgICAgICAgICAgICAgIGRlYnVnKGAke2N1cnJlbnRwfSBpcyBubyBsb25nZXIgYSBzeW1saW5rIHNpbmNlICR7Y3VycmVudHB9ID09ICR7bmV3U3ltbGlua1BhdGh9YCk7XG4gICAgICAgICAgICAgICAgICAgIG5vZGVbVHlwZVN5bWJvbF0gPSAyIC8qIFR5cGUuRklMRSAqLztcbiAgICAgICAgICAgICAgICAgICAgZGVsZXRlIG5vZGVbU3ltbGlua1N5bWJvbF07XG4gICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICAgIGVsc2UgaWYgKG5vZGVbU3ltbGlua1N5bWJvbF0gIT0gbmV3U3ltbGlua1BhdGgpIHtcbiAgICAgICAgICAgICAgICAgICAgZGVidWcoYHVwZGF0aW5nIHN5bWxpbmsgJHtjdXJyZW50cH0gZnJvbSAke25vZGVbU3ltbGlua1N5bWJvbF19IHRvICR7bmV3U3ltbGlua1BhdGh9YCk7XG4gICAgICAgICAgICAgICAgICAgIG5vZGVbU3ltbGlua1N5bWJvbF0gPSBuZXdTeW1saW5rUGF0aDtcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgbm90aWZ5V2F0Y2hlcnMocGFyZW50LCBzZWdtZW50LCBub2RlW1R5cGVTeW1ib2xdLCAxIC8qIEV2ZW50VHlwZS5VUERBVEVEICovKTtcbiAgICAgICAgICAgICAgICByZXR1cm47IC8vIHJldHVybiB0aGUgbG9vcCBhcyB3ZSBkb24ndCBhbnl0aGluZyB0byBiZSBzeW1saW5rcyBmcm9tIG9uO1xuICAgICAgICAgICAgfVxuICAgICAgICB9XG4gICAgICAgIC8vIGRpZCBub3QgZW5jb3VudGVyIGFueSBzeW1saW5rcyBhbG9uZyB0aGUgd2F5LiBpdCdzIGEgRElSIG9yIEZJTEUgYXQgdGhpcyBwb2ludC5cbiAgICAgICAgY29uc3QgYmFzZW5hbWUgPSBwYXJlbnQucG9wKCk7XG4gICAgICAgIG5vdGlmeVdhdGNoZXJzKHBhcmVudCwgYmFzZW5hbWUsIG5vZGVbVHlwZVN5bWJvbF0sIDEgLyogRXZlbnRUeXBlLlVQREFURUQgKi8pO1xuICAgIH1cbiAgICBmdW5jdGlvbiBub3RpZnkocCkge1xuICAgICAgICBjb25zdCBkaXJuYW1lID0gcGF0aC5kaXJuYW1lKHApO1xuICAgICAgICBjb25zdCBiYXNlbmFtZSA9IHBhdGguYmFzZW5hbWUocCk7XG4gICAgICAgIG5vdGlmeVdhdGNoZXJzKGRpcm5hbWUuc3BsaXQocGF0aC5zZXApLCBiYXNlbmFtZSwgMiAvKiBUeXBlLkZJTEUgKi8sIDAgLyogRXZlbnRUeXBlLkFEREVEICovKTtcbiAgICB9XG4gICAgZnVuY3Rpb24gZmlsZUV4aXN0cyhwKSB7XG4gICAgICAgIGNvbnN0IG5vZGUgPSBnZXROb2RlKHApO1xuICAgICAgICByZXR1cm4gdHlwZW9mIG5vZGUgPT0gXCJvYmplY3RcIiAmJiBub2RlW1R5cGVTeW1ib2xdID09IDIgLyogVHlwZS5GSUxFICovO1xuICAgIH1cbiAgICBmdW5jdGlvbiBkaXJlY3RvcnlFeGlzdHMocCkge1xuICAgICAgICBjb25zdCBub2RlID0gZ2V0Tm9kZShwKTtcbiAgICAgICAgcmV0dXJuIHR5cGVvZiBub2RlID09IFwib2JqZWN0XCIgJiYgbm9kZVtUeXBlU3ltYm9sXSA9PSAxIC8qIFR5cGUuRElSICovO1xuICAgIH1cbiAgICBmdW5jdGlvbiBub3JtYWxpemVJZlN5bWxpbmsocCkge1xuICAgICAgICBjb25zdCBzZWdtZW50cyA9IHAuc3BsaXQocGF0aC5zZXApO1xuICAgICAgICBsZXQgbm9kZSA9IHRyZWU7XG4gICAgICAgIGxldCBwYXJlbnRzID0gW107XG4gICAgICAgIGZvciAoY29uc3Qgc2VnbWVudCBvZiBzZWdtZW50cykge1xuICAgICAgICAgICAgaWYgKCFzZWdtZW50KSB7XG4gICAgICAgICAgICAgICAgY29udGludWU7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBpZiAoIShzZWdtZW50IGluIG5vZGUpKSB7XG4gICAgICAgICAgICAgICAgYnJlYWs7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBub2RlID0gbm9kZVtzZWdtZW50XTtcbiAgICAgICAgICAgIHBhcmVudHMucHVzaChzZWdtZW50KTtcbiAgICAgICAgICAgIGlmIChub2RlW1R5cGVTeW1ib2xdID09IDMgLyogVHlwZS5TWU1MSU5LICovKSB7XG4gICAgICAgICAgICAgICAgLy8gaWRlYWxseSB0aGlzIGNvbmRpdGlvbiB3b3VsZCBub3QgbWV0IHVudGlsIHRoZSBsYXN0IHNlZ21lbnQgb2YgdGhlIHBhdGggdW5sZXNzIHRoZXJlJ3MgYSBzeW1saW5rIHNlZ21lbnQgaW5cbiAgICAgICAgICAgICAgICAvLyBlYXJsaWVyIHNlZ21lbnRzLiB0aGlzIGluZGVlZCBoYXBwZW5zIGluIGJhemVsIDYuMCB3aXRoIC0tZXhwZXJpbWVudGFsX2FsbG93X3VucmVzb2x2ZWRfc3ltbGlua3MgdHVybmVkIG9mZi5cbiAgICAgICAgICAgICAgICBicmVhaztcbiAgICAgICAgICAgIH1cbiAgICAgICAgfVxuICAgICAgICBpZiAodHlwZW9mIG5vZGUgPT0gXCJvYmplY3RcIiAmJiBub2RlW1R5cGVTeW1ib2xdID09IDMgLyogVHlwZS5TWU1MSU5LICovKSB7XG4gICAgICAgICAgICByZXR1cm4gcGFyZW50cy5qb2luKHBhdGguc2VwKTtcbiAgICAgICAgfVxuICAgICAgICByZXR1cm4gdW5kZWZpbmVkO1xuICAgIH1cbiAgICBmdW5jdGlvbiByZWFscGF0aChwKSB7XG4gICAgICAgIGNvbnN0IHNlZ21lbnRzID0gcC5zcGxpdChwYXRoLnNlcCk7XG4gICAgICAgIGxldCBub2RlID0gdHJlZTtcbiAgICAgICAgbGV0IGN1cnJlbnRQYXRoID0gXCJcIjtcbiAgICAgICAgZm9yIChjb25zdCBzZWdtZW50IG9mIHNlZ21lbnRzKSB7XG4gICAgICAgICAgICBpZiAoIXNlZ21lbnQpIHtcbiAgICAgICAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIGlmICghKHNlZ21lbnQgaW4gbm9kZSkpIHtcbiAgICAgICAgICAgICAgICBicmVhaztcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIG5vZGUgPSBub2RlW3NlZ21lbnRdO1xuICAgICAgICAgICAgY3VycmVudFBhdGggPSBwYXRoLmpvaW4oY3VycmVudFBhdGgsIHNlZ21lbnQpO1xuICAgICAgICAgICAgaWYgKG5vZGVbVHlwZVN5bWJvbF0gPT0gMyAvKiBUeXBlLlNZTUxJTksgKi8pIHtcbiAgICAgICAgICAgICAgICBjdXJyZW50UGF0aCA9IG5vZGVbU3ltbGlua1N5bWJvbF07XG4gICAgICAgICAgICAgICAgbm9kZSA9IGdldE5vZGUobm9kZVtTeW1saW5rU3ltYm9sXSk7XG4gICAgICAgICAgICAgICAgLy8gZGFuZ2xpbmcgc3ltbGluazsgc3ltbGlua3MgcG9pbnQgdG8gYSBub24tZXhpc3RpbmcgcGF0aC4gY2FuJ3QgZm9sbG93IGl0XG4gICAgICAgICAgICAgICAgaWYgKCFub2RlKSB7XG4gICAgICAgICAgICAgICAgICAgIGJyZWFrO1xuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgIH1cbiAgICAgICAgfVxuICAgICAgICByZXR1cm4gcGF0aC5pc0Fic29sdXRlKGN1cnJlbnRQYXRoKSA/IGN1cnJlbnRQYXRoIDogXCIvXCIgKyBjdXJyZW50UGF0aDtcbiAgICB9XG4gICAgZnVuY3Rpb24gcmVhZERpcmVjdG9yeShwLCBleHRlbnNpb25zLCBleGNsdWRlLCBpbmNsdWRlLCBkZXB0aCkge1xuICAgICAgICBjb25zdCBub2RlID0gZ2V0Tm9kZShwKTtcbiAgICAgICAgaWYgKCFub2RlIHx8IG5vZGVbVHlwZVN5bWJvbF0gIT0gMSAvKiBUeXBlLkRJUiAqLykge1xuICAgICAgICAgICAgcmV0dXJuIFtdO1xuICAgICAgICB9XG4gICAgICAgIGNvbnN0IHJlc3VsdCA9IFtdO1xuICAgICAgICBsZXQgY3VycmVudERlcHRoID0gMDtcbiAgICAgICAgY29uc3Qgd2FsayA9IChwLCBub2RlKSA9PiB7XG4gICAgICAgICAgICBjdXJyZW50RGVwdGgrKztcbiAgICAgICAgICAgIGZvciAoY29uc3Qga2V5IGluIG5vZGUpIHtcbiAgICAgICAgICAgICAgICBjb25zdCBzdWJwID0gcGF0aC5qb2luKHAsIGtleSk7XG4gICAgICAgICAgICAgICAgY29uc3Qgc3Vibm9kZSA9IG5vZGVba2V5XTtcbiAgICAgICAgICAgICAgICByZXN1bHQucHVzaChzdWJwKTtcbiAgICAgICAgICAgICAgICBpZiAoc3Vibm9kZVtUeXBlU3ltYm9sXSA9PSAxIC8qIFR5cGUuRElSICovKSB7XG4gICAgICAgICAgICAgICAgICAgIGlmIChjdXJyZW50RGVwdGggPj0gZGVwdGggfHwgIWRlcHRoKSB7XG4gICAgICAgICAgICAgICAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICAgICAgICB3YWxrKHN1YnAsIHN1Ym5vZGUpO1xuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgICBlbHNlIGlmIChzdWJub2RlW1R5cGVTeW1ib2xdID09IDMgLyogVHlwZS5TWU1MSU5LICovKSB7XG4gICAgICAgICAgICAgICAgICAgIGNvbnRpbnVlO1xuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgIH1cbiAgICAgICAgfTtcbiAgICAgICAgd2FsayhwLCBub2RlKTtcbiAgICAgICAgcmV0dXJuIHJlc3VsdDtcbiAgICB9XG4gICAgZnVuY3Rpb24gZ2V0RGlyZWN0b3JpZXMocCkge1xuICAgICAgICBjb25zdCBub2RlID0gZ2V0Tm9kZShwKTtcbiAgICAgICAgaWYgKCFub2RlKSB7XG4gICAgICAgICAgICByZXR1cm4gW107XG4gICAgICAgIH1cbiAgICAgICAgY29uc3QgZGlycyA9IFtdO1xuICAgICAgICBmb3IgKGNvbnN0IHBhcnQgaW4gbm9kZSkge1xuICAgICAgICAgICAgbGV0IHN1Ym5vZGUgPSBub2RlW3BhcnRdO1xuICAgICAgICAgICAgaWYgKHN1Ym5vZGVbVHlwZVN5bWJvbF0gPT0gMyAvKiBUeXBlLlNZTUxJTksgKi8pIHtcbiAgICAgICAgICAgICAgICAvLyBnZXQgdGhlIG5vZGUgd2hlcmUgdGhlIHN5bWxpbmsgcG9pbnRzIHRvXG4gICAgICAgICAgICAgICAgc3Vibm9kZSA9IGdldE5vZGUoc3Vibm9kZVtTeW1saW5rU3ltYm9sXSk7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBpZiAoc3Vibm9kZVtUeXBlU3ltYm9sXSA9PSAxIC8qIFR5cGUuRElSICovKSB7XG4gICAgICAgICAgICAgICAgZGlycy5wdXNoKHBhcnQpO1xuICAgICAgICAgICAgfVxuICAgICAgICB9XG4gICAgICAgIHJldHVybiBkaXJzO1xuICAgIH1cbiAgICBmdW5jdGlvbiBub3RpZnlXYXRjaGVycyh0cmFpbCwgc2VnbWVudCwgdHlwZSwgZXZlbnRUeXBlKSB7XG4gICAgICAgIGNvbnN0IGZpbmFsID0gWy4uLnRyYWlsLCBzZWdtZW50XTtcbiAgICAgICAgY29uc3QgZmluYWxQYXRoID0gZmluYWwuam9pbihwYXRoLnNlcCk7XG4gICAgICAgIGlmICh0eXBlID09IDIgLyogVHlwZS5GSUxFICovKSB7XG4gICAgICAgICAgICAvLyBub3RpZnkgZmlsZSB3YXRjaGVycyB3YXRjaGluZyBhdCB0aGUgZmlsZSBwYXRoLCBleGNsdWRpbmcgcmVjdXJzaXZlIG9uZXMuIFxuICAgICAgICAgICAgbm90aWZ5V2F0Y2hlcihmaW5hbCwgZmluYWxQYXRoLCBldmVudFR5cGUsIC8qIHJlY3Vyc2l2ZSAqLyBmYWxzZSk7XG4gICAgICAgICAgICAvLyBub3RpZnkgZGlyZWN0b3J5IHdhdGNoZXJzIHdhdGNoaW5nIGF0IHRoZSBwYXJlbnQgb2YgdGhlIGZpbGUsIGluY2x1ZGluZyB0aGUgcmVjdXJzaXZlIGRpcmVjdG9yeSB3YXRjaGVycyBhdCBwYXJlbnQuXG4gICAgICAgICAgICBub3RpZnlXYXRjaGVyKHRyYWlsLCBmaW5hbFBhdGgsIGV2ZW50VHlwZSk7XG4gICAgICAgIH1cbiAgICAgICAgZWxzZSB7XG4gICAgICAgICAgICAvLyBub3RpZnkgZGlyZWN0b3J5IHdhdGNoZXJzIHdhdGNoaW5nIGF0IHRoZSBwYXJlbnQgb2YgdGhlIGRpcmVjdG9yeSwgaW5jbHVkaW5nIHJlY3Vyc2l2ZSBvbmVzLlxuICAgICAgICAgICAgbm90aWZ5V2F0Y2hlcih0cmFpbCwgZmluYWxQYXRoLCBldmVudFR5cGUpO1xuICAgICAgICB9XG4gICAgICAgIC8vIHJlY3Vyc2l2ZWx5IGludm9rZSB3YXRjaGVycyBzdGFydGluZyBmcm9tIHRyYWlsO1xuICAgICAgICAvLyAgZ2l2ZW4gcGF0aCBgL3BhdGgvdG8vc29tZXRoaW5nL2Vsc2VgXG4gICAgICAgIC8vIHRoaXMgbG9vcCB3aWxsIGNhbGwgd2F0Y2hlcnMgYWxsIGF0IGBzZWdtZW50YCB3aXRoIGNvbWJpbmF0aW9uIG9mIHRoZXNlIGFyZ3VtZW50cztcbiAgICAgICAgLy8gIHBhcmVudCA9IC9wYXRoL3RvL3NvbWV0aGluZyAgICAgcGF0aCA9IC9wYXRoL3RvL3NvbWV0aGluZy9lbHNlXG4gICAgICAgIC8vICBwYXJlbnQgPSAvcGF0aC90byAgICAgICAgICAgICAgIHBhdGggPSAvcGF0aC90by9zb21ldGhpbmcvZWxzZVxuICAgICAgICAvLyAgcGFyZW50ID0gL3BhdGggICAgICAgICAgICAgICAgICBwYXRoID0gL3BhdGgvdG8vc29tZXRoaW5nL2Vsc2VcbiAgICAgICAgbGV0IHBhcmVudCA9IFsuLi50cmFpbF07XG4gICAgICAgIHdoaWxlIChwYXJlbnQubGVuZ3RoKSB7XG4gICAgICAgICAgICBwYXJlbnQucG9wKCk7XG4gICAgICAgICAgICAvLyBpbnZva2Ugb25seSByZWN1cnNpdmUgd2F0Y2hlcnNcbiAgICAgICAgICAgIG5vdGlmeVdhdGNoZXIocGFyZW50LCBmaW5hbFBhdGgsIGV2ZW50VHlwZSwgdHJ1ZSk7XG4gICAgICAgIH1cbiAgICB9XG4gICAgZnVuY3Rpb24gbm90aWZ5V2F0Y2hlcihwYXJlbnQsIHBhdGgsIGV2ZW50VHlwZSwgcmVjdXJzaXZlKSB7XG4gICAgICAgIGxldCBub2RlID0gZ2V0V2F0Y2hlck5vZGUocGFyZW50KTtcbiAgICAgICAgaWYgKHR5cGVvZiBub2RlID09IFwib2JqZWN0XCIgJiYgV2F0Y2hlclN5bWJvbCBpbiBub2RlKSB7XG4gICAgICAgICAgICBmb3IgKGNvbnN0IHdhdGNoZXIgb2Ygbm9kZVtXYXRjaGVyU3ltYm9sXSkge1xuICAgICAgICAgICAgICAgIC8vIGlmIHJlY3Vyc2l2ZSBhcmd1bWVudCBpc24ndCBwcm92aWRlZCwgaW52b2tlIGJvdGggcmVjdXJzaXZlIGFuZCBub24tcmVjdXJzaXZlIHdhdGNoZXJzLlxuICAgICAgICAgICAgICAgIGlmIChyZWN1cnNpdmUgIT0gdW5kZWZpbmVkICYmIHdhdGNoZXIucmVjdXJzaXZlICE9IHJlY3Vyc2l2ZSkge1xuICAgICAgICAgICAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgd2F0Y2hlci5jYWxsYmFjayhwYXRoLCBldmVudFR5cGUpO1xuICAgICAgICAgICAgfVxuICAgICAgICB9XG4gICAgfVxuICAgIGZ1bmN0aW9uIGdldFdhdGNoZXJOb2RlKHBhcnRzKSB7XG4gICAgICAgIGxldCBub2RlID0gd2F0Y2hpbmdUcmVlO1xuICAgICAgICBmb3IgKGNvbnN0IHBhcnQgb2YgcGFydHMpIHtcbiAgICAgICAgICAgIGlmICghKHBhcnQgaW4gbm9kZSkpIHtcbiAgICAgICAgICAgICAgICByZXR1cm4gdW5kZWZpbmVkO1xuICAgICAgICAgICAgfVxuICAgICAgICAgICAgbm9kZSA9IG5vZGVbcGFydF07XG4gICAgICAgIH1cbiAgICAgICAgcmV0dXJuIG5vZGU7XG4gICAgfVxuICAgIGZ1bmN0aW9uIHdhdGNoKHAsIGNhbGxiYWNrLCByZWN1cnNpdmUgPSBmYWxzZSkge1xuICAgICAgICBjb25zdCBwYXJ0cyA9IHAuc3BsaXQocGF0aC5zZXApO1xuICAgICAgICBsZXQgbm9kZSA9IHdhdGNoaW5nVHJlZTtcbiAgICAgICAgZm9yIChjb25zdCBwYXJ0IG9mIHBhcnRzKSB7XG4gICAgICAgICAgICBpZiAoIXBhcnQpIHtcbiAgICAgICAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIGlmICghKHBhcnQgaW4gbm9kZSkpIHtcbiAgICAgICAgICAgICAgICBub2RlW3BhcnRdID0ge307XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBub2RlID0gbm9kZVtwYXJ0XTtcbiAgICAgICAgfVxuICAgICAgICBpZiAoIShXYXRjaGVyU3ltYm9sIGluIG5vZGUpKSB7XG4gICAgICAgICAgICBub2RlW1dhdGNoZXJTeW1ib2xdID0gbmV3IFNldCgpO1xuICAgICAgICB9XG4gICAgICAgIGNvbnN0IHdhdGNoZXIgPSB7IGNhbGxiYWNrLCByZWN1cnNpdmUgfTtcbiAgICAgICAgbm9kZVtXYXRjaGVyU3ltYm9sXS5hZGQod2F0Y2hlcik7XG4gICAgICAgIHJldHVybiAoKSA9PiBub2RlW1dhdGNoZXJTeW1ib2xdLmRlbGV0ZSh3YXRjaGVyKTtcbiAgICB9XG4gICAgZnVuY3Rpb24gd2F0Y2hGaWxlKHAsIGNhbGxiYWNrKSB7XG4gICAgICAgIHJldHVybiB3YXRjaChwLCBjYWxsYmFjayk7XG4gICAgfVxuICAgIHJldHVybiB7IGFkZCwgcmVtb3ZlLCB1cGRhdGUsIG5vdGlmeSwgZmlsZUV4aXN0cywgZGlyZWN0b3J5RXhpc3RzLCBub3JtYWxpemVJZlN5bWxpbmssIHJlYWxwYXRoLCByZWFkRGlyZWN0b3J5LCBnZXREaXJlY3Rvcmllcywgd2F0Y2hEaXJlY3Rvcnk6IHdhdGNoLCB3YXRjaEZpbGU6IHdhdGNoRmlsZSwgcHJpbnRUcmVlIH07XG59XG4vLyMgc291cmNlTWFwcGluZ1VSTD12ZnMuanMubWFwIiwiaW1wb3J0IHsgZGVidWcgfSBmcm9tIFwiLi9kZWJ1Z2dpbmdcIjtcbmltcG9ydCB7IG5vb3AsIG5vdEltcGxlbWVudGVkIH0gZnJvbSBcIi4vdXRpbFwiO1xuaW1wb3J0ICogYXMgcGF0aCBmcm9tIFwibm9kZTpwYXRoXCI7XG5pbXBvcnQgKiBhcyB2OCBmcm9tIFwidjhcIjtcbmltcG9ydCAqIGFzIHRzIGZyb20gXCJ0eXBlc2NyaXB0XCI7XG5pbXBvcnQgeyBjcmVhdGVGaWxlc3lzdGVtVHJlZSB9IGZyb20gXCIuL3Zmc1wiO1xuY29uc3Qgd29ya2VycyA9IG5ldyBNYXAoKTtcbmNvbnN0IGxpYkNhY2hlID0gbmV3IE1hcCgpO1xuY29uc3QgTk9UX0ZST01fU09VUkNFID0gU3ltYm9sLmZvcihcIk5PVF9GUk9NX1NPVVJDRVwiKTtcbmNvbnN0IE5FQVJfT09NX1pPTkUgPSAyMDsgLy8gSG93IG11Y2ggKCUpIG9mIG1lbW9yeSBzaG91bGQgYmUgZnJlZSBhdCBhbGwgdGltZXMuIFxuY29uc3QgU1lOVEhFVElDX09VVERJUiA9IFwiX19zdF9vdXRkaXJfX1wiO1xuZXhwb3J0IGZ1bmN0aW9uIGlzTmVhck9vbVpvbmUoKSB7XG4gICAgY29uc3Qgc3RhdCA9IHY4LmdldEhlYXBTdGF0aXN0aWNzKCk7XG4gICAgY29uc3QgdXNlZCA9ICgxMDAgLyBzdGF0LmhlYXBfc2l6ZV9saW1pdCkgKiBzdGF0LnVzZWRfaGVhcF9zaXplO1xuICAgIHJldHVybiAxMDAgLSB1c2VkIDwgTkVBUl9PT01fWk9ORTtcbn1cbmV4cG9ydCBmdW5jdGlvbiBzd2VlcExlYXN0UmVjZW50bHlVc2VkV29ya2VycygpIHtcbiAgICBmb3IgKGNvbnN0IFtrLCB3XSBvZiB3b3JrZXJzKSB7XG4gICAgICAgIGRlYnVnKGBnYXJiYWdlIGNvbGxlY3Rpb246IHJlbW92aW5nICR7a30gdG8gZnJlZSBtZW1vcnkuYCk7XG4gICAgICAgIHcucHJvZ3JhbS5jbG9zZSgpO1xuICAgICAgICB3b3JrZXJzLmRlbGV0ZShrKTtcbiAgICAgICAgLy8gc3RvcCBraWxsaW5nIHdvcmtlcnMgYXMgc29vbiBhcyB0aGUgd29ya2VyIGlzIG91dCB0aGUgb29tIHpvbmUgXG4gICAgICAgIGlmICghaXNOZWFyT29tWm9uZSgpKSB7XG4gICAgICAgICAgICBkZWJ1ZyhgZ2FyYmFnZSBjb2xsZWN0aW9uOiBmaW5pc2hlZGApO1xuICAgICAgICAgICAgYnJlYWs7XG4gICAgICAgIH1cbiAgICB9XG59XG5leHBvcnQgZnVuY3Rpb24gZ2V0T3JDcmVhdGVXb3JrZXIoYXJncywgaW5wdXRzLCBvdXRwdXQpIHtcbiAgICBpZiAoaXNOZWFyT29tWm9uZSgpKSB7XG4gICAgICAgIHN3ZWVwTGVhc3RSZWNlbnRseVVzZWRXb3JrZXJzKCk7XG4gICAgfVxuICAgIGNvbnN0IHByb2plY3QgPSBhcmdzW2FyZ3MuaW5kZXhPZignLS1wcm9qZWN0JykgKyAxXTtcbiAgICBjb25zdCBvdXREaXIgPSBhcmdzW2FyZ3MubGFzdEluZGV4T2YoXCItLW91dERpclwiKSArIDFdO1xuICAgIGNvbnN0IGRlY2xhcmF0aW9uRGlyID0gYXJnc1thcmdzLmxhc3RJbmRleE9mKFwiLS1kZWNsYXJhdGlvbkRpclwiKSArIDFdO1xuICAgIGNvbnN0IHJvb3REaXIgPSBhcmdzW2FyZ3MubGFzdEluZGV4T2YoXCItLXJvb3REaXJcIikgKyAxXTtcbiAgICBjb25zdCBrZXkgPSBgJHtwcm9qZWN0fSBAICR7b3V0RGlyfSBAICR7ZGVjbGFyYXRpb25EaXJ9IEAgJHtyb290RGlyfWA7XG4gICAgbGV0IHdvcmtlciA9IHdvcmtlcnMuZ2V0KGtleSk7XG4gICAgaWYgKCF3b3JrZXIpIHtcbiAgICAgICAgZGVidWcoYGNyZWF0aW5nIGEgbmV3IHdvcmtlciB3aXRoIHRoZSBrZXkgJHtrZXl9YCk7XG4gICAgICAgIHdvcmtlciA9IGNyZWF0ZVByb2dyYW0oYXJncywgaW5wdXRzLCBvdXRwdXQsIChleGl0Q29kZSkgPT4ge1xuICAgICAgICAgICAgZGVidWcoYHdvcmtlciAke2tleX0gaGFzIHF1aXQgcHJlbWF0dXJlbHkgd2l0aCBjb2RlICR7ZXhpdENvZGV9YCk7XG4gICAgICAgICAgICB3b3JrZXJzLmRlbGV0ZShrZXkpO1xuICAgICAgICB9KTtcbiAgICB9XG4gICAgZWxzZSB7XG4gICAgICAgIC8vIE5COiByZW1vdmVkIGZyb20gdGhlIG1hcCBpbnRlbnRpb25hbGx5LiB0byBhY2hpZXZlIExSVSBlZmZlY3Qgb24gdGhlIHdvcmtlcnMgbWFwLlxuICAgICAgICB3b3JrZXJzLmRlbGV0ZShrZXkpO1xuICAgIH1cbiAgICB3b3JrZXJzLnNldChrZXksIHdvcmtlcik7XG4gICAgcmV0dXJuIHdvcmtlcjtcbn1cbmV4cG9ydCBmdW5jdGlvbiB0ZXN0T25seUdldFdvcmtlcnMoKSB7XG4gICAgcmV0dXJuIHdvcmtlcnM7XG59XG5mdW5jdGlvbiBpc0V4dGVybmFsTGliKHBhdGgpIHtcbiAgICByZXR1cm4gcGF0aC5pbmNsdWRlcygnZXh0ZXJuYWwnKSAmJlxuICAgICAgICBwYXRoLmluY2x1ZGVzKCd0eXBlc2NyaXB0QCcpICYmXG4gICAgICAgIHBhdGguaW5jbHVkZXMoJ25vZGVfbW9kdWxlcy90eXBlc2NyaXB0L2xpYicpO1xufVxuZnVuY3Rpb24gY3JlYXRlRW1pdEFuZExpYkNhY2hlQW5kRGlhZ25vc3RpY3NQcm9ncmFtKHJvb3ROYW1lcywgb3B0aW9ucywgaG9zdCwgb2xkUHJvZ3JhbSwgY29uZmlnRmlsZVBhcnNpbmdEaWFnbm9zdGljcywgcHJvamVjdFJlZmVyZW5jZXMpIHtcbiAgICBjb25zdCBidWlsZGVyID0gdHMuY3JlYXRlRW1pdEFuZFNlbWFudGljRGlhZ25vc3RpY3NCdWlsZGVyUHJvZ3JhbShyb290TmFtZXMsIG9wdGlvbnMsIGhvc3QsIG9sZFByb2dyYW0sIGNvbmZpZ0ZpbGVQYXJzaW5nRGlhZ25vc3RpY3MsIHByb2plY3RSZWZlcmVuY2VzKTtcbiAgICAvKiogRW1pdCBDYWNoZSAqL1xuICAgIGNvbnN0IG91dHB1dFNvdXJjZU1hcHBpbmcgPSAoaG9zdFtcIm91dHB1dFNvdXJjZU1hcHBpbmdcIl0gPSBob3N0W1wib3V0cHV0U291cmNlTWFwcGluZ1wiXSB8fCBuZXcgTWFwKCkpO1xuICAgIC8qKiBAdHlwZSB7TWFwPHN0cmluZywge3RleHQ6IHN0cmluZywgd3JpdGVCeXRlT3JkZXJNYXJrOiBib29sZWFufT59ICovXG4gICAgY29uc3Qgb3V0cHV0Q2FjaGUgPSAoaG9zdFtcIm91dHB1dENhY2hlXCJdID0gaG9zdFtcIm91dHB1dENhY2hlXCJdIHx8IG5ldyBNYXAoKSk7XG4gICAgY29uc3QgZW1pdCA9IGJ1aWxkZXIuZW1pdDtcbiAgICBidWlsZGVyLmVtaXQgPSAodGFyZ2V0U291cmNlRmlsZSwgd3JpdGVGaWxlLCBjYW5jZWxsYXRpb25Ub2tlbiwgZW1pdE9ubHlEdHNGaWxlcywgY3VzdG9tVHJhbnNmb3JtZXJzKSA9PiB7XG4gICAgICAgIGNvbnN0IHdyaXRlID0gd3JpdGVGaWxlIHx8IGhvc3Qud3JpdGVGaWxlO1xuICAgICAgICBpZiAoIXRhcmdldFNvdXJjZUZpbGUpIHtcbiAgICAgICAgICAgIGZvciAoY29uc3QgW3BhdGgsIGVudHJ5XSBvZiBvdXRwdXRDYWNoZS5lbnRyaWVzKCkpIHtcbiAgICAgICAgICAgICAgICBjb25zdCBzb3VyY2VQYXRoID0gb3V0cHV0U291cmNlTWFwcGluZy5nZXQocGF0aCk7XG4gICAgICAgICAgICAgICAgaWYgKHNvdXJjZVBhdGggPT0gTk9UX0ZST01fU09VUkNFKSB7XG4gICAgICAgICAgICAgICAgICAgIHdyaXRlKHBhdGgsIGVudHJ5LnRleHQsIGVudHJ5LndyaXRlQnl0ZU9yZGVyTWFyayk7XG4gICAgICAgICAgICAgICAgICAgIGNvbnRpbnVlO1xuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgICAvLyBpdCBhIGZpbGUgdGhhdCBoYXMgdG8gdGllcyB0byBhIHNvdXJjZSBmaWxlXG4gICAgICAgICAgICAgICAgaWYgKHNvdXJjZVBhdGggPT0gTk9UX0ZST01fU09VUkNFKSB7XG4gICAgICAgICAgICAgICAgICAgIGNvbnRpbnVlO1xuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgICBlbHNlIGlmICghYnVpbGRlci5nZXRTb3VyY2VGaWxlKHNvdXJjZVBhdGgpKSB7XG4gICAgICAgICAgICAgICAgICAgIC8vIHNvdXJjZSBpcyBub3QgcGFydCBvZiB0aGUgcHJvZ3JhbSBhbnltb3JlLCBzbyBkcm9wIHRoZSBvdXRwdXQgZnJvbSB0aGUgb3V0cHV0IGNhY2hlLlxuICAgICAgICAgICAgICAgICAgICBkZWJ1ZyhgY3JlYXRlRW1pdEFuZExpYkNhY2hlQW5kRGlhZ25vc3RpY3NQcm9ncmFtOiBkZWxldGluZyAke3NvdXJjZVBhdGh9IGFzIGl0J3Mgbm8gbG9uZ2VyIGEgc3JjLmApO1xuICAgICAgICAgICAgICAgICAgICBvdXRwdXRTb3VyY2VNYXBwaW5nLmRlbGV0ZShwYXRoKTtcbiAgICAgICAgICAgICAgICAgICAgb3V0cHV0Q2FjaGUuZGVsZXRlKHBhdGgpO1xuICAgICAgICAgICAgICAgICAgICBjb250aW51ZTtcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICAgICAgY29uc3Qgd3JpdGVGID0gKGZpbGVOYW1lLCB0ZXh0LCB3cml0ZUJ5dGVPcmRlck1hcmssIG9uRXJyb3IsIHNvdXJjZUZpbGVzKSA9PiB7XG4gICAgICAgICAgICB3cml0ZShmaWxlTmFtZSwgdGV4dCwgd3JpdGVCeXRlT3JkZXJNYXJrLCBvbkVycm9yLCBzb3VyY2VGaWxlcyk7XG4gICAgICAgICAgICBvdXRwdXRDYWNoZS5zZXQoZmlsZU5hbWUsIHsgdGV4dCwgd3JpdGVCeXRlT3JkZXJNYXJrIH0pO1xuICAgICAgICAgICAgaWYgKHNvdXJjZUZpbGVzPy5sZW5ndGggJiYgc291cmNlRmlsZXM/Lmxlbmd0aCA+IDApIHtcbiAgICAgICAgICAgICAgICBvdXRwdXRTb3VyY2VNYXBwaW5nLnNldChmaWxlTmFtZSwgc291cmNlRmlsZXNbMF0uZmlsZU5hbWUpO1xuICAgICAgICAgICAgfVxuICAgICAgICAgICAgZWxzZSB7XG4gICAgICAgICAgICAgICAgLy8gaWYgdGhlIGZpbGUgd3JpdGUgaXMgbm90IHRoZSByZXN1bHQgb2YgYSBzb3VyY2UgbWFyayBpdCBhcyBub3QgZnJvbSBzb3VyY2Ugbm90IGF2b2lkIGNhY2hlIGRyb3BzLlxuICAgICAgICAgICAgICAgIG91dHB1dFNvdXJjZU1hcHBpbmcuc2V0KGZpbGVOYW1lLCBOT1RfRlJPTV9TT1VSQ0UpO1xuICAgICAgICAgICAgfVxuICAgICAgICB9O1xuICAgICAgICByZXR1cm4gZW1pdCh0YXJnZXRTb3VyY2VGaWxlLCB3cml0ZUYsIGNhbmNlbGxhdGlvblRva2VuLCBlbWl0T25seUR0c0ZpbGVzLCBjdXN0b21UcmFuc2Zvcm1lcnMpO1xuICAgIH07XG4gICAgLyoqIExpYiBDYWNoZSAqL1xuICAgIGNvbnN0IGdldFNvdXJjZUZpbGUgPSBob3N0LmdldFNvdXJjZUZpbGU7XG4gICAgaG9zdC5nZXRTb3VyY2VGaWxlID0gKGZpbGVOYW1lLCBsYW5ndWFnZVZlcnNpb25Pck9wdGlvbnMsIG9uRXJyb3IsIHNob3VsZENyZWF0ZU5ld1NvdXJjZUZpbGUpID0+IHtcbiAgICAgICAgaWYgKGxpYkNhY2hlLmhhcyhmaWxlTmFtZSkpIHtcbiAgICAgICAgICAgIHJldHVybiBsaWJDYWNoZS5nZXQoZmlsZU5hbWUpO1xuICAgICAgICB9XG4gICAgICAgIGNvbnN0IHNmID0gZ2V0U291cmNlRmlsZShmaWxlTmFtZSwgbGFuZ3VhZ2VWZXJzaW9uT3JPcHRpb25zLCBvbkVycm9yLCBzaG91bGRDcmVhdGVOZXdTb3VyY2VGaWxlKTtcbiAgICAgICAgaWYgKHNmICYmIGlzRXh0ZXJuYWxMaWIoZmlsZU5hbWUpKSB7XG4gICAgICAgICAgICBkZWJ1ZyhgY3JlYXRlRW1pdEFuZExpYkNhY2hlQW5kRGlhZ25vc3RpY3NQcm9ncmFtOiBwdXR0aW5nIGRlZmF1bHQgbGliICR7ZmlsZU5hbWV9IGludG8gY2FjaGUuYCk7XG4gICAgICAgICAgICBsaWJDYWNoZS5zZXQoZmlsZU5hbWUsIHNmKTtcbiAgICAgICAgfVxuICAgICAgICByZXR1cm4gc2Y7XG4gICAgfTtcbiAgICByZXR1cm4gYnVpbGRlcjtcbn1cbmZ1bmN0aW9uIGNyZWF0ZVByb2dyYW0oYXJncywgaW5wdXRzLCBvdXRwdXQsIGV4aXQpIHtcbiAgICBjb25zdCBjbWQgPSB0cy5wYXJzZUNvbW1hbmRMaW5lKGFyZ3MpO1xuICAgIGNvbnN0IGJpbiA9IHByb2Nlc3MuY3dkKCk7IC8vIDxleGVjcm9vdD4vYmF6ZWwtYmluLzxjZmc+L2JpblxuICAgIGNvbnN0IGV4ZWNyb290ID0gcGF0aC5yZXNvbHZlKGJpbiwgJy4uJywgJy4uJywgJy4uJyk7IC8vIGV4ZWNyb290XG4gICAgY29uc3QgdHNjb25maWcgPSBwYXRoLnJlbGF0aXZlKGV4ZWNyb290LCBwYXRoLnJlc29sdmUoYmluLCBjbWQub3B0aW9ucy5wcm9qZWN0KSk7IC8vIGJhemVsLWJpbi88Y2ZnPi9iaW4vPHBrZz4vPG9wdGlvbnMucHJvamVjdD5cbiAgICBjb25zdCBjZmcgPSBwYXRoLnJlbGF0aXZlKGV4ZWNyb290LCBiaW4pOyAvLyAvYmF6ZWwtYmluLzxjZmc+L2JpblxuICAgIGNvbnN0IGV4ZWN1dGluZ2ZpbGVwYXRoID0gcGF0aC5yZWxhdGl2ZShleGVjcm9vdCwgcmVxdWlyZS5yZXNvbHZlKFwidHlwZXNjcmlwdFwiKSk7IC8vIC9iYXplbC1iaW4vPG9wdC1jZmc+L2Jpbi9ub2RlX21vZHVsZXMvdHNjLy4uLlxuICAgIGNvbnN0IGZpbGVzeXN0ZW0gPSBjcmVhdGVGaWxlc3lzdGVtVHJlZShleGVjcm9vdCwgaW5wdXRzKTtcbiAgICBjb25zdCBvdXRwdXRzID0gbmV3IFNldCgpO1xuICAgIGNvbnN0IHdhdGNoRXZlbnRRdWV1ZSA9IG5ldyBBcnJheSgpO1xuICAgIGNvbnN0IHdhdGNoRXZlbnRzRm9yU3ltbGlua3MgPSBuZXcgU2V0KCk7XG4gICAgY29uc3Qgc3RyaWN0U3lzID0ge1xuICAgICAgICB3cml0ZTogd3JpdGUsXG4gICAgICAgIHdyaXRlT3V0cHV0SXNUVFk6ICgpID0+IGZhbHNlLFxuICAgICAgICBnZXRDdXJyZW50RGlyZWN0b3J5OiAoKSA9PiBcIi9cIiArIGNmZyxcbiAgICAgICAgZ2V0RXhlY3V0aW5nRmlsZVBhdGg6ICgpID0+IFwiL1wiICsgZXhlY3V0aW5nZmlsZXBhdGgsXG4gICAgICAgIGV4aXQ6IGV4aXQsXG4gICAgICAgIHJlc29sdmVQYXRoOiBub3RJbXBsZW1lbnRlZChcInN5cy5yZXNvbHZlUGF0aFwiLCB0cnVlLCAwKSxcbiAgICAgICAgLy8gaGFuZGxlZCBieSBmc3RyZWUuXG4gICAgICAgIHJlYWxwYXRoOiBmaWxlc3lzdGVtLnJlYWxwYXRoLFxuICAgICAgICBmaWxlRXhpc3RzOiBmaWxlc3lzdGVtLmZpbGVFeGlzdHMsXG4gICAgICAgIGRpcmVjdG9yeUV4aXN0czogZmlsZXN5c3RlbS5kaXJlY3RvcnlFeGlzdHMsXG4gICAgICAgIGdldERpcmVjdG9yaWVzOiBmaWxlc3lzdGVtLmdldERpcmVjdG9yaWVzLFxuICAgICAgICByZWFkRmlsZTogcmVhZEZpbGUsXG4gICAgICAgIHJlYWREaXJlY3Rvcnk6IGZpbGVzeXN0ZW0ucmVhZERpcmVjdG9yeSxcbiAgICAgICAgY3JlYXRlRGlyZWN0b3J5OiBjcmVhdGVEaXJlY3RvcnksXG4gICAgICAgIHdyaXRlRmlsZTogd3JpdGVGaWxlLFxuICAgICAgICB3YXRjaEZpbGU6IHdhdGNoRmlsZSxcbiAgICAgICAgd2F0Y2hEaXJlY3Rvcnk6IHdhdGNoRGlyZWN0b3J5XG4gICAgfTtcbiAgICBjb25zdCBzeXMgPSB7IC4uLnRzLnN5cywgLi4uc3RyaWN0U3lzIH07XG4gICAgY29uc3QgaG9zdCA9IHRzLmNyZWF0ZVdhdGNoQ29tcGlsZXJIb3N0KGNtZC5vcHRpb25zLnByb2plY3QsIGNtZC5vcHRpb25zLCBzeXMsIGNyZWF0ZUVtaXRBbmRMaWJDYWNoZUFuZERpYWdub3N0aWNzUHJvZ3JhbSwgbm9vcCwgbm9vcCk7XG4gICAgLy8gZGVsZXRpbmcgdGhpcyB3aWxsIG1ha2UgdHNjIHRvIG5vdCBzY2hlZHVsZSB1cGRhdGVzIGJ1dCB3YWl0IGZvciBnZXRQcm9ncmFtIHRvIGJlIGNhbGxlZCB0byBhcHBseSB1cGRhdGVzIHdoaWNoIGlzIGV4YWN0bHkgd2hhdCBpcyBuZWVkZWQuXG4gICAgZGVsZXRlIGhvc3Quc2V0VGltZW91dDtcbiAgICBkZWxldGUgaG9zdC5jbGVhclRpbWVvdXQ7XG4gICAgY29uc3QgZm9ybWF0RGlhZ25vc3RpY0hvc3QgPSB7XG4gICAgICAgIGdldENhbm9uaWNhbEZpbGVOYW1lOiAocGF0aCkgPT4gcGF0aCxcbiAgICAgICAgZ2V0Q3VycmVudERpcmVjdG9yeTogc3lzLmdldEN1cnJlbnREaXJlY3RvcnksXG4gICAgICAgIGdldE5ld0xpbmU6ICgpID0+IHN5cy5uZXdMaW5lLFxuICAgIH07XG4gICAgZGVidWcoYHRzY29uZmlnOiAke3RzY29uZmlnfWApO1xuICAgIGRlYnVnKGBleGVjcm9vdDogJHtleGVjcm9vdH1gKTtcbiAgICBkZWJ1ZyhgYmluOiAke2Jpbn1gKTtcbiAgICBkZWJ1ZyhgY2ZnOiAke2NmZ31gKTtcbiAgICBkZWJ1ZyhgZXhlY3V0aW5nZmlsZXBhdGg6ICR7ZXhlY3V0aW5nZmlsZXBhdGh9YCk7XG4gICAgbGV0IGNvbXBpbGVyT3B0aW9ucyA9IHJlYWRDb21waWxlck9wdGlvbnMoKTtcbiAgICBlbmFibGVTdGF0aXN0aWNzQW5kVHJhY2luZygpO1xuICAgIHVwZGF0ZU91dHB1dHMoKTtcbiAgICBhcHBseVN5bnRoZXRpY091dFBhdGhzKCk7XG4gICAgY29uc3QgcHJvZ3JhbSA9IHRzLmNyZWF0ZVdhdGNoUHJvZ3JhbShob3N0KTtcbiAgICAvLyBlYXJseSByZXR1cm4gdG8gcHJldmVudCBmcm9tIGRlY2xhcmluZyBtb3JlIHZhcmlhYmxlcyBhY2NpZGVudGlhbGx5LiBcbiAgICByZXR1cm4geyBwcm9ncmFtLCBhcHBseUFyZ3MsIHNldE91dHB1dCwgZm9ybWF0RGlhZ25vc3RpY3MsIGZsdXNoV2F0Y2hFdmVudHMsIGludmFsaWRhdGUsIHBvc3RSdW4sIHByaW50RlNUcmVlOiBmaWxlc3lzdGVtLnByaW50VHJlZSB9O1xuICAgIGZ1bmN0aW9uIGZvcm1hdERpYWdub3N0aWNzKGRpYWdub3N0aWNzKSB7XG4gICAgICAgIHJldHVybiBgXFxuJHt0cy5mb3JtYXREaWFnbm9zdGljcyhkaWFnbm9zdGljcywgZm9ybWF0RGlhZ25vc3RpY0hvc3QpfVxcbmA7XG4gICAgfVxuICAgIGZ1bmN0aW9uIHNldE91dHB1dChuZXdPdXRwdXQpIHtcbiAgICAgICAgb3V0cHV0ID0gbmV3T3V0cHV0O1xuICAgIH1cbiAgICBmdW5jdGlvbiB3cml0ZShjaHVuaykge1xuICAgICAgICBvdXRwdXQud3JpdGUoY2h1bmspO1xuICAgIH1cbiAgICBmdW5jdGlvbiBlbnF1ZXVlQWRkaXRpb25hbFdhdGNoRXZlbnRzRm9yU3ltbGlua3MoKSB7XG4gICAgICAgIGZvciAoY29uc3Qgc3ltbGluayBvZiB3YXRjaEV2ZW50c0ZvclN5bWxpbmtzKSB7XG4gICAgICAgICAgICBjb25zdCBleHBhbmRlZElucHV0cyA9IGZpbGVzeXN0ZW0ucmVhZERpcmVjdG9yeShzeW1saW5rLCB1bmRlZmluZWQsIHVuZGVmaW5lZCwgdW5kZWZpbmVkLCBJbmZpbml0eSk7XG4gICAgICAgICAgICBmb3IgKGNvbnN0IGlucHV0IG9mIGV4cGFuZGVkSW5wdXRzKSB7XG4gICAgICAgICAgICAgICAgZmlsZXN5c3RlbS5ub3RpZnkoaW5wdXQpO1xuICAgICAgICAgICAgfVxuICAgICAgICB9XG4gICAgICAgIHdhdGNoRXZlbnRzRm9yU3ltbGlua3MuY2xlYXIoKTtcbiAgICB9XG4gICAgZnVuY3Rpb24gZmx1c2hXYXRjaEV2ZW50cygpIHtcbiAgICAgICAgZW5xdWV1ZUFkZGl0aW9uYWxXYXRjaEV2ZW50c0ZvclN5bWxpbmtzKCk7XG4gICAgICAgIGZvciAoY29uc3QgW2NhbGxiYWNrLCAuLi5hcmdzXSBvZiB3YXRjaEV2ZW50UXVldWUpIHtcbiAgICAgICAgICAgIGNhbGxiYWNrKC4uLmFyZ3MpO1xuICAgICAgICB9XG4gICAgICAgIHdhdGNoRXZlbnRRdWV1ZS5sZW5ndGggPSAwO1xuICAgIH1cbiAgICBmdW5jdGlvbiBpbnZhbGlkYXRlKGZpbGVQYXRoLCBraW5kKSB7XG4gICAgICAgIGRlYnVnKGBpbnZhbGlkYXRlICR7ZmlsZVBhdGh9IDogJHt0cy5GaWxlV2F0Y2hlckV2ZW50S2luZFtraW5kXX1gKTtcbiAgICAgICAgaWYgKGtpbmQgPT09IHRzLkZpbGVXYXRjaGVyRXZlbnRLaW5kLkNoYW5nZWQgJiYgZmlsZVBhdGggPT0gdHNjb25maWcpIHtcbiAgICAgICAgICAgIGFwcGx5Q2hhbmdlc0ZvclRzQ29uZmlnKGFyZ3MpO1xuICAgICAgICB9XG4gICAgICAgIGlmIChraW5kID09PSB0cy5GaWxlV2F0Y2hlckV2ZW50S2luZC5EZWxldGVkKSB7XG4gICAgICAgICAgICBmaWxlc3lzdGVtLnJlbW92ZShmaWxlUGF0aCk7XG4gICAgICAgIH1cbiAgICAgICAgZWxzZSBpZiAoa2luZCA9PT0gdHMuRmlsZVdhdGNoZXJFdmVudEtpbmQuQ3JlYXRlZCkge1xuICAgICAgICAgICAgZmlsZXN5c3RlbS5hZGQoZmlsZVBhdGgpO1xuICAgICAgICB9XG4gICAgICAgIGVsc2Uge1xuICAgICAgICAgICAgZmlsZXN5c3RlbS51cGRhdGUoZmlsZVBhdGgpO1xuICAgICAgICB9XG4gICAgICAgIGlmIChmaWxlUGF0aC5pbmRleE9mKFwibm9kZV9tb2R1bGVzXCIpICE9IC0xICYmIGtpbmQgPT09IHRzLkZpbGVXYXRjaGVyRXZlbnRLaW5kLkNyZWF0ZWQpIHtcbiAgICAgICAgICAgIGNvbnN0IG5vcm1hbGl6ZWRGaWxlUGF0aCA9IGZpbGVzeXN0ZW0ubm9ybWFsaXplSWZTeW1saW5rKGZpbGVQYXRoKTtcbiAgICAgICAgICAgIGlmIChub3JtYWxpemVkRmlsZVBhdGgpIHtcbiAgICAgICAgICAgICAgICB3YXRjaEV2ZW50c0ZvclN5bWxpbmtzLmFkZChub3JtYWxpemVkRmlsZVBhdGgpO1xuICAgICAgICAgICAgfVxuICAgICAgICB9XG4gICAgfVxuICAgIGZ1bmN0aW9uIGVuYWJsZVN0YXRpc3RpY3NBbmRUcmFjaW5nKCkge1xuICAgICAgICBpZiAoY29tcGlsZXJPcHRpb25zLmRpYWdub3N0aWNzIHx8IGNvbXBpbGVyT3B0aW9ucy5leHRlbmRlZERpYWdub3N0aWNzIHx8IGhvc3Qub3B0aW9uc1RvRXh0ZW5kLmRpYWdub3N0aWNzIHx8IGhvc3Qub3B0aW9uc1RvRXh0ZW5kLmV4dGVuZGVkRGlhZ25vc3RpY3MpIHtcbiAgICAgICAgICAgIHRzW1wicGVyZm9ybWFuY2VcIl0uZW5hYmxlKCk7XG4gICAgICAgIH1cbiAgICAgICAgLy8gdHJhY2luZyBpcyBvbmx5IGF2YWlsYWJsZSBpbiA0LjEgYW5kIGFib3ZlXG4gICAgICAgIC8vIFNlZTogaHR0cHM6Ly9naXRodWIuY29tL21pY3Jvc29mdC9UeXBlU2NyaXB0L3dpa2kvUGVyZm9ybWFuY2UtVHJhY2luZ1xuICAgICAgICBpZiAoKGNvbXBpbGVyT3B0aW9ucy5nZW5lcmF0ZVRyYWNlIHx8IGhvc3Qub3B0aW9uc1RvRXh0ZW5kLmdlbmVyYXRlVHJhY2UpICYmIHRzW1wic3RhcnRUcmFjaW5nXCJdICYmICF0c1tcInRyYWNpbmdcIl0pIHtcbiAgICAgICAgICAgIHRzW1wic3RhcnRUcmFjaW5nXCJdKCdidWlsZCcsIGNvbXBpbGVyT3B0aW9ucy5nZW5lcmF0ZVRyYWNlIHx8IGhvc3Qub3B0aW9uc1RvRXh0ZW5kLmdlbmVyYXRlVHJhY2UpO1xuICAgICAgICB9XG4gICAgfVxuICAgIGZ1bmN0aW9uIGRpc2FibGVTdGF0aXN0aWNzQW5kVHJhY2luZygpIHtcbiAgICAgICAgdHNbXCJwZXJmb3JtYW5jZVwiXS5kaXNhYmxlKCk7XG4gICAgICAgIGlmICh0c1tcInRyYWNpbmdcIl0pIHtcbiAgICAgICAgICAgIHRzW1widHJhY2luZ1wiXS5zdG9wVHJhY2luZygpO1xuICAgICAgICB9XG4gICAgfVxuICAgIGZ1bmN0aW9uIHBvc3RSdW4oKSB7XG4gICAgICAgIGlmICh0c1tcInBlcmZvcm1hbmNlXCJdICYmIHRzW1wicGVyZm9ybWFuY2VcIl0uaXNFbmFibGVkKCkpIHtcbiAgICAgICAgICAgIHRzW1wicGVyZm9ybWFuY2VcIl0uZGlzYWJsZSgpO1xuICAgICAgICAgICAgdHNbXCJwZXJmb3JtYW5jZVwiXS5lbmFibGUoKTtcbiAgICAgICAgfVxuICAgICAgICBpZiAodHNbXCJ0cmFjaW5nXCJdKSB7XG4gICAgICAgICAgICB0c1tcInRyYWNpbmdcIl0uc3RvcFRyYWNpbmcoKTtcbiAgICAgICAgfVxuICAgIH1cbiAgICBmdW5jdGlvbiB1cGRhdGVPdXRwdXRzKCkge1xuICAgICAgICBvdXRwdXRzLmNsZWFyKCk7XG4gICAgICAgIGlmIChob3N0Lm9wdGlvbnNUb0V4dGVuZC50c0J1aWxkSW5mb0ZpbGUgfHwgY29tcGlsZXJPcHRpb25zLnRzQnVpbGRJbmZvRmlsZSkge1xuICAgICAgICAgICAgY29uc3QgcCA9IHBhdGguam9pbihzeXMuZ2V0Q3VycmVudERpcmVjdG9yeSgpLCBob3N0Lm9wdGlvbnNUb0V4dGVuZC50c0J1aWxkSW5mb0ZpbGUpO1xuICAgICAgICAgICAgb3V0cHV0cy5hZGQocCk7XG4gICAgICAgIH1cbiAgICB9XG4gICAgZnVuY3Rpb24gYXBwbHlTeW50aGV0aWNPdXRQYXRocygpIHtcbiAgICAgICAgaG9zdC5vcHRpb25zVG9FeHRlbmQub3V0RGlyID0gYCR7aG9zdC5vcHRpb25zVG9FeHRlbmQub3V0RGlyfS8ke1NZTlRIRVRJQ19PVVRESVJ9YDtcbiAgICAgICAgaWYgKGhvc3Qub3B0aW9uc1RvRXh0ZW5kLmRlY2xhcmF0aW9uRGlyKSB7XG4gICAgICAgICAgICBob3N0Lm9wdGlvbnNUb0V4dGVuZC5kZWNsYXJhdGlvbkRpciA9IGAke2hvc3Qub3B0aW9uc1RvRXh0ZW5kLmRlY2xhcmF0aW9uRGlyfS8ke1NZTlRIRVRJQ19PVVRESVJ9YDtcbiAgICAgICAgfVxuICAgIH1cbiAgICBmdW5jdGlvbiBhcHBseUFyZ3MobmV3QXJncykge1xuICAgICAgICAvLyBUaGlzIGZ1bmN0aW9uIHdvcmtzIGJhc2VkIG9uIHRoZSBhc3N1bXB0aW9uIHRoYXQgcGFyc2VDb25maWdGaWxlIG9mIGNyZWF0ZVdhdGNoUHJvZ3JhbSB3aWxsIGFsd2F5cyByZWFkIG9wdGlvbnNUb0V4dGVuZCBieSByZWZlcmVuY2UuXG4gICAgICAgIC8vIFNlZTogaHR0cHM6Ly9naXRodWIuY29tL21pY3Jvc29mdC9UeXBlU2NyaXB0L2Jsb2IvMmVjZGUyNzE4NzIyZDY2NDM3NzNkNDMzOTBhYTU3YzNlMzE5OTM2NS9zcmMvY29tcGlsZXIvd2F0Y2hQdWJsaWMudHMjTDczNVxuICAgICAgICAvLyBhbmQ6IGh0dHBzOi8vZ2l0aHViLmNvbS9taWNyb3NvZnQvVHlwZVNjcmlwdC9ibG9iLzJlY2RlMjcxODcyMmQ2NjQzNzczZDQzMzkwYWE1N2MzZTMxOTkzNjUvc3JjL2NvbXBpbGVyL3dhdGNoUHVibGljLnRzI0wyOTZcbiAgICAgICAgaWYgKGFyZ3Muam9pbignICcpICE9IG5ld0FyZ3Muam9pbignICcpKSB7XG4gICAgICAgICAgICBkZWJ1ZyhgYXJndW1lbnRzIGhhdmUgY2hhbmdlZC5gKTtcbiAgICAgICAgICAgIGRlYnVnKGAgIGN1cnJlbnQ6ICR7bmV3QXJncy5qb2luKFwiIFwiKX1gKTtcbiAgICAgICAgICAgIGRlYnVnKGAgIHByZXZpb3VzOiAke2FyZ3Muam9pbihcIiBcIil9YCk7XG4gICAgICAgICAgICBhcHBseUNoYW5nZXNGb3JUc0NvbmZpZyhhcmdzKTtcbiAgICAgICAgICAgIC8vIGludmFsaWRhdGluZyB0c2NvbmZpZyB3aWxsIGNhdXNlIHBhcnNlQ29uZmlnRmlsZSB0byBiZSBpbnZva2VkXG4gICAgICAgICAgICBmaWxlc3lzdGVtLnVwZGF0ZSh0c2NvbmZpZyk7XG4gICAgICAgICAgICBhcmdzID0gbmV3QXJncztcbiAgICAgICAgfVxuICAgIH1cbiAgICBmdW5jdGlvbiByZWFkQ29tcGlsZXJPcHRpb25zKCkge1xuICAgICAgICBjb25zdCByYXcgPSB0cy5yZWFkQ29uZmlnRmlsZShjbWQub3B0aW9ucy5wcm9qZWN0LCByZWFkRmlsZSk7XG4gICAgICAgIGNvbnN0IHBhcnNlZENvbW1hbmRMaW5lID0gdHMucGFyc2VKc29uQ29uZmlnRmlsZUNvbnRlbnQocmF3LmNvbmZpZywgc3lzLCBwYXRoLmRpcm5hbWUoY21kLm9wdGlvbnMucHJvamVjdCkpO1xuICAgICAgICByZXR1cm4gcGFyc2VkQ29tbWFuZExpbmUub3B0aW9ucyB8fCB7fTtcbiAgICB9XG4gICAgZnVuY3Rpb24gYXBwbHlDaGFuZ2VzRm9yVHNDb25maWcoYXJncykge1xuICAgICAgICBjb25zdCBjbWQgPSB0cy5wYXJzZUNvbW1hbmRMaW5lKGFyZ3MpO1xuICAgICAgICBmb3IgKGNvbnN0IGtleSBpbiBob3N0Lm9wdGlvbnNUb0V4dGVuZCkge1xuICAgICAgICAgICAgZGVsZXRlIGhvc3Qub3B0aW9uc1RvRXh0ZW5kW2tleV07XG4gICAgICAgIH1cbiAgICAgICAgZm9yIChjb25zdCBrZXkgaW4gY21kLm9wdGlvbnMpIHtcbiAgICAgICAgICAgIGhvc3Qub3B0aW9uc1RvRXh0ZW5kW2tleV0gPSBjbWQub3B0aW9uc1trZXldO1xuICAgICAgICB9XG4gICAgICAgIGNvbXBpbGVyT3B0aW9ucyA9IHJlYWRDb21waWxlck9wdGlvbnMoKTtcbiAgICAgICAgZGlzYWJsZVN0YXRpc3RpY3NBbmRUcmFjaW5nKCk7XG4gICAgICAgIGVuYWJsZVN0YXRpc3RpY3NBbmRUcmFjaW5nKCk7XG4gICAgICAgIHVwZGF0ZU91dHB1dHMoKTtcbiAgICAgICAgYXBwbHlTeW50aGV0aWNPdXRQYXRocygpO1xuICAgIH1cbiAgICBmdW5jdGlvbiByZWFkRmlsZShmaWxlUGF0aCwgZW5jb2RpbmcpIHtcbiAgICAgICAgZmlsZVBhdGggPSBwYXRoLnJlc29sdmUoc3lzLmdldEN1cnJlbnREaXJlY3RvcnkoKSwgZmlsZVBhdGgpO1xuICAgICAgICAvL2V4dGVybmFsIGxpYiBhcmUgdHJhbnNpdGl2ZSBzb3VyY2VzIHRodXMgbm90IGxpc3RlZCBpbiB0aGUgaW5wdXRzIG1hcCByZXBvcnRlZCBieSBiYXplbC5cbiAgICAgICAgaWYgKCFmaWxlc3lzdGVtLmZpbGVFeGlzdHMoZmlsZVBhdGgpICYmICFpc0V4dGVybmFsTGliKGZpbGVQYXRoKSAmJiAhb3V0cHV0cy5oYXMoZmlsZVBhdGgpKSB7XG4gICAgICAgICAgICBvdXRwdXQud3JpdGUoYHRzYyB0cmllZCB0byByZWFkIGZpbGUgKCR7ZmlsZVBhdGh9KSB0aGF0IHdhc24ndCBhbiBpbnB1dCB0byBpdC5gICsgXCJcXG5cIik7XG4gICAgICAgICAgICB0aHJvdyBuZXcgRXJyb3IoYHRzYyB0cmllZCB0byByZWFkIGZpbGUgKCR7ZmlsZVBhdGh9KSB0aGF0IHdhc24ndCBhbiBpbnB1dCB0byBpdC5gKTtcbiAgICAgICAgfVxuICAgICAgICByZXR1cm4gdHMuc3lzLnJlYWRGaWxlKHBhdGguam9pbihleGVjcm9vdCwgZmlsZVBhdGgpLCBlbmNvZGluZyk7XG4gICAgfVxuICAgIGZ1bmN0aW9uIGNyZWF0ZURpcmVjdG9yeShwKSB7XG4gICAgICAgIHAgPSBwLnJlcGxhY2UoU1lOVEhFVElDX09VVERJUiwgXCJcIik7XG4gICAgICAgIHRzLnN5cy5jcmVhdGVEaXJlY3RvcnkocCk7XG4gICAgfVxuICAgIGZ1bmN0aW9uIHdyaXRlRmlsZShwLCBkYXRhLCB3cml0ZUJ5dGVPcmRlck1hcmspIHtcbiAgICAgICAgcCA9IHAucmVwbGFjZShTWU5USEVUSUNfT1VURElSLCBcIlwiKTtcbiAgICAgICAgaWYgKHAuZW5kc1dpdGgoXCIubWFwXCIpKSB7XG4gICAgICAgICAgICAvLyBXZSBuZWVkIHRvIHBvc3Rwcm9jZXNzIG1hcCBmaWxlcyB0byBmaXggcGF0aHMgZm9yIHRoZSBzb3VyY2VzLiBUaGlzIGlzIHJlcXVpcmVkIGJlY2F1c2Ugd2UgaGF2ZSBhIFNZTlRIRVRJQ19PVVRESVIgc3VmZml4IGFuZCBcbiAgICAgICAgICAgIC8vIHRzYyB0cmllcyB0byByZWxhdGl2aXRpemUgc291cmNlcyBiYWNrIHRvIHJvb3REaXIuIGluIG9yZGVyIHRvIGZpeCBpdCB0aGUgbGVhZGluZyBgLi4vYCBuZWVkZWQgdG8gYmUgc3RyaXBwZWQgb3V0LlxuICAgICAgICAgICAgLy8gV2UgdHJpZWQgYSBmZXcgb3B0aW9ucyB0byBtYWtlIHRzYyBkbyB0aGlzIGZvciB1cy5cbiAgICAgICAgICAgIC8vIFxuICAgICAgICAgICAgLy8gMS0gVXNpbmcgbWFwUm9vdCB0byByZXJvb3QgbWFwIGZpbGVzLiBUaGlzIGRpZG4ndCB3b3JrIGJlY2F1c2UgZWl0aGVyIHBhdGggaW4gYHNvdXJjZU1hcHBpbmdVcmxgIG9yIHBhdGggaW4gYHNvdXJjZXNgIHdhcyBpbmNvcnJlY3QuXG4gICAgICAgICAgICAvLyBcbiAgICAgICAgICAgIC8vIDItIFVzaW5nIGEgY29udmVyZ2luZyBwYXJlbnQgcGF0aCBmb3IgYG91dERpcmAgYW5kIGByb290RGlyYCBzbyB0c2MgcmVyb290cyBzb3VyY2VtYXBzIHRvIHRoYXQgZGlyZWN0b3J5LiBUaGlzIGRpZG4ndCB3b3JrIGVpdGhlciBiZWNhdXNlXG4gICAgICAgICAgICAvLyBldmVudGhvdWdoIHRoZSBjb252ZXJnaW5nIHBhcmVudCBwYXRoIGxvb2tlZCBjb3JyZWN0IGluIGEgc3VicGFja2FnZSwgaXQgd2FzIGluY29ycmVjdCBhdCB0aGUgcm9vdCBkaXJlY3RvcnkgYmVjYXVzZSBgLi4vYCBwb2ludGVkIHRvIG91dCBcbiAgICAgICAgICAgIC8vIG9mIG91dHB1dCB0cmVlLlxuICAgICAgICAgICAgLy8gXG4gICAgICAgICAgICAvLyBUaGlzIGxlZnQgdXMgd2l0aCBwb3N0LXByb2Nlc3NpbmcgdGhlIGAubWFwYCBmaWxlcyBzbyB0aGF0IHBhdGhzIGxvb2tzIGNvcnJlY3QuXG4gICAgICAgICAgICBjb25zdCBzb3VyY2VHcm91cCA9IGRhdGEubWF0Y2goL1wic291cmNlc1wiOlxcWy4qP10vKS5hdCgwKTtcbiAgICAgICAgICAgIGNvbnN0IGZpeGVkU291cmNlR3JvdXAgPSBzb3VyY2VHcm91cC5yZXBsYWNlKC9cIi4uXFwvL2csIGBcImApO1xuICAgICAgICAgICAgZGF0YSA9IGRhdGEucmVwbGFjZShzb3VyY2VHcm91cCwgZml4ZWRTb3VyY2VHcm91cCk7XG4gICAgICAgIH1cbiAgICAgICAgdHMuc3lzLndyaXRlRmlsZShwLCBkYXRhLCB3cml0ZUJ5dGVPcmRlck1hcmspO1xuICAgIH1cbiAgICBmdW5jdGlvbiB3YXRjaERpcmVjdG9yeShkaXJlY3RvcnlQYXRoLCBjYWxsYmFjaywgcmVjdXJzaXZlLCBvcHRpb25zKSB7XG4gICAgICAgIGNvbnN0IGNsb3NlID0gZmlsZXN5c3RlbS53YXRjaERpcmVjdG9yeShkaXJlY3RvcnlQYXRoLCAoaW5wdXQpID0+IHdhdGNoRXZlbnRRdWV1ZS5wdXNoKFtjYWxsYmFjaywgcGF0aC5qb2luKFwiL1wiLCBpbnB1dCldKSwgcmVjdXJzaXZlKTtcbiAgICAgICAgcmV0dXJuIHsgY2xvc2UgfTtcbiAgICB9XG4gICAgZnVuY3Rpb24gd2F0Y2hGaWxlKGZpbGVQYXRoLCBjYWxsYmFjaywgcG9sbGluZ0ludGVydmFsLCBvcHRpb25zKSB7XG4gICAgICAgIC8vIGlkZWFsbHksIGFsbCBwYXRocyBzaG91bGQgYmUgYWJzb2x1dGUgYnV0IHNvbWV0aW1lcyB0c2MgcGFzc2VzIHJlbGF0aXZlIG9uZXMuXG4gICAgICAgIGZpbGVQYXRoID0gcGF0aC5yZXNvbHZlKHN5cy5nZXRDdXJyZW50RGlyZWN0b3J5KCksIGZpbGVQYXRoKTtcbiAgICAgICAgY29uc3QgY2xvc2UgPSBmaWxlc3lzdGVtLndhdGNoRmlsZShmaWxlUGF0aCwgKGlucHV0LCBraW5kKSA9PiB3YXRjaEV2ZW50UXVldWUucHVzaChbY2FsbGJhY2ssIHBhdGguam9pbihcIi9cIiwgaW5wdXQpLCBraW5kXSkpO1xuICAgICAgICByZXR1cm4geyBjbG9zZSB9O1xuICAgIH1cbn1cbi8vIyBzb3VyY2VNYXBwaW5nVVJMPXByb2dyYW0uanMubWFwIiwiY29uc3QgdHMgPSByZXF1aXJlKCd0eXBlc2NyaXB0Jyk7XG4vLyB3b3JrYXJvdW5kIGZvciB0aGUgaXNzdWUgaW50cm9kdWNlZCBpbiBodHRwczovL2dpdGh1Yi5jb20vbWljcm9zb2Z0L1R5cGVTY3JpcHQvcHVsbC80MjA5NVxuaWYgKEFycmF5LmlzQXJyYXkodHNbXCJpZ25vcmVkUGF0aHNcIl0pKSB7XG4gICAgdHNbXCJpZ25vcmVkUGF0aHNcIl0gPSB0c1tcImlnbm9yZWRQYXRoc1wiXS5maWx0ZXIoaWdub3JlZFBhdGggPT4gaWdub3JlZFBhdGggIT0gXCIvbm9kZV9tb2R1bGVzLy5cIik7XG59XG4vLyMgc291cmNlTWFwcGluZ1VSTD1wYXRjaGVzLmpzLm1hcCIsImltcG9ydCB7IGRlYnVnLCBpc1ZlcmJvc2UsIHNldFZlcmJvc2l0eSB9IGZyb20gXCIuL2RlYnVnZ2luZ1wiO1xuaW1wb3J0IHsgZ2V0T3JDcmVhdGVXb3JrZXIsIHRlc3RPbmx5R2V0V29ya2VycyB9IGZyb20gXCIuL3Byb2dyYW1cIjtcbmltcG9ydCAqIGFzIGZzIGZyb20gXCJub2RlOmZzXCI7XG5pbXBvcnQgKiBhcyBwYXRoIGZyb20gXCJub2RlOnBhdGhcIjtcbmltcG9ydCAqIGFzIHRzIGZyb20gXCJ0eXBlc2NyaXB0XCI7XG5pbXBvcnQgeyBub29wIH0gZnJvbSBcIi4vdXRpbFwiO1xuaW1wb3J0IFwiLi9wYXRjaGVzXCI7XG5pbXBvcnQgeyBjcmVhdGVGaWxlc3lzdGVtVHJlZSB9IGZyb20gXCIuL3Zmc1wiO1xuY29uc3Qgd29ya2VyX3Byb3RvY29sID0gcmVxdWlyZSgnLi93b3JrZXInKTtcbmNvbnN0IE1ORU1PTklDID0gJ1RzUHJvamVjdCc7XG5mdW5jdGlvbiB0aW1pbmdTdGFydChsYWJlbCkge1xuICAgIC8vIEB0cy1leHBlY3QtZXJyb3JcbiAgICB0cy5wZXJmb3JtYW5jZS5tYXJrKGBiZWZvcmUke2xhYmVsfWApO1xufVxuZnVuY3Rpb24gdGltaW5nRW5kKGxhYmVsKSB7XG4gICAgLy8gQHRzLWV4cGVjdC1lcnJvclxuICAgIHRzLnBlcmZvcm1hbmNlLm1hcmsoYGFmdGVyJHtsYWJlbH1gKTtcbiAgICAvLyBAdHMtZXhwZWN0LWVycm9yXG4gICAgdHMucGVyZm9ybWFuY2UubWVhc3VyZShgJHtNTkVNT05JQ30gJHtsYWJlbH1gLCBgYmVmb3JlJHtsYWJlbH1gLCBgYWZ0ZXIke2xhYmVsfWApO1xufVxuZnVuY3Rpb24gY3JlYXRlQ2FuY2VsbGF0aW9uVG9rZW4oc2lnbmFsKSB7XG4gICAgcmV0dXJuIHtcbiAgICAgICAgaXNDYW5jZWxsYXRpb25SZXF1ZXN0ZWQ6ICgpID0+IHNpZ25hbC5hYm9ydGVkLFxuICAgICAgICB0aHJvd0lmQ2FuY2VsbGF0aW9uUmVxdWVzdGVkOiAoKSA9PiB7XG4gICAgICAgICAgICBpZiAoc2lnbmFsLmFib3J0ZWQpIHtcbiAgICAgICAgICAgICAgICB0aHJvdyBuZXcgRXJyb3Ioc2lnbmFsLnJlYXNvbik7XG4gICAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICB9O1xufVxuLyoqIEJ1aWxkICovXG5hc3luYyBmdW5jdGlvbiBlbWl0KHJlcXVlc3QpIHtcbiAgICBzZXRWZXJib3NpdHkocmVxdWVzdC52ZXJib3NpdHkpO1xuICAgIGRlYnVnKGAjIEJlZ2lubmluZyBuZXcgd29ya2ApO1xuICAgIGRlYnVnKGBhcmd1bWVudHM6ICR7cmVxdWVzdC5hcmd1bWVudHMuam9pbignICcpfWApO1xuICAgIGNvbnN0IGlucHV0cyA9IE9iamVjdC5mcm9tRW50cmllcyhyZXF1ZXN0LmlucHV0cy5tYXAoKGlucHV0KSA9PiBbXG4gICAgICAgIGlucHV0LnBhdGgsXG4gICAgICAgIGlucHV0LmRpZ2VzdC5ieXRlTGVuZ3RoID8gQnVmZmVyLmZyb20oaW5wdXQuZGlnZXN0KS50b1N0cmluZyhcImhleFwiKSA6IG51bGxcbiAgICBdKSk7XG4gICAgY29uc3Qgd29ya2VyID0gZ2V0T3JDcmVhdGVXb3JrZXIocmVxdWVzdC5hcmd1bWVudHMsIGlucHV0cywgcHJvY2Vzcy5zdGRlcnIpO1xuICAgIGNvbnN0IGNhbmNlbGxhdGlvblRva2VuID0gY3JlYXRlQ2FuY2VsbGF0aW9uVG9rZW4ocmVxdWVzdC5zaWduYWwpO1xuICAgIGlmICh3b3JrZXIucHJldmlvdXNJbnB1dHMpIHtcbiAgICAgICAgY29uc3QgcHJldmlvdXNJbnB1dHMgPSB3b3JrZXIucHJldmlvdXNJbnB1dHM7XG4gICAgICAgIHRpbWluZ1N0YXJ0KCdhcHBseUFyZ3MnKTtcbiAgICAgICAgd29ya2VyLmFwcGx5QXJncyhyZXF1ZXN0LmFyZ3VtZW50cyk7XG4gICAgICAgIHRpbWluZ0VuZCgnYXBwbHlBcmdzJyk7XG4gICAgICAgIGNvbnN0IGNoYW5nZXMgPSBuZXcgU2V0KCksIGNyZWF0aW9ucyA9IG5ldyBTZXQoKTtcbiAgICAgICAgdGltaW5nU3RhcnQoYGludmFsaWRhdGVgKTtcbiAgICAgICAgZm9yIChjb25zdCBbaW5wdXQsIGRpZ2VzdF0gb2YgT2JqZWN0LmVudHJpZXMoaW5wdXRzKSkge1xuICAgICAgICAgICAgaWYgKCEoaW5wdXQgaW4gcHJldmlvdXNJbnB1dHMpKSB7XG4gICAgICAgICAgICAgICAgY3JlYXRpb25zLmFkZChpbnB1dCk7XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBlbHNlIGlmIChwcmV2aW91c0lucHV0c1tpbnB1dF0gIT0gZGlnZXN0KSB7XG4gICAgICAgICAgICAgICAgY2hhbmdlcy5hZGQoaW5wdXQpO1xuICAgICAgICAgICAgfVxuICAgICAgICAgICAgZWxzZSBpZiAocHJldmlvdXNJbnB1dHNbaW5wdXRdID09IG51bGwgJiYgZGlnZXN0ID09IG51bGwpIHtcbiAgICAgICAgICAgICAgICAvLyBBc3N1bWUgc3ltbGlua3MgYWx3YXlzIGNoYW5nZS4gYmF6ZWwgPD0gNS4zIHdpbGwgYWx3YXlzIHJlcG9ydCBzeW1saW5rcyB3aXRob3V0IGEgZGlnZXN0LlxuICAgICAgICAgICAgICAgIC8vIHRoZXJlZm9yZSB0aGVyZSBpcyBubyB3YXkgdG8gZGV0ZXJtaW5lIGlmIGEgc3ltbGluayBoYXMgY2hhbmdlZC4gXG4gICAgICAgICAgICAgICAgY2hhbmdlcy5hZGQoaW5wdXQpO1xuICAgICAgICAgICAgfVxuICAgICAgICB9XG4gICAgICAgIGZvciAoY29uc3QgaW5wdXQgaW4gcHJldmlvdXNJbnB1dHMpIHtcbiAgICAgICAgICAgIGlmICghKGlucHV0IGluIGlucHV0cykpIHtcbiAgICAgICAgICAgICAgICB3b3JrZXIuaW52YWxpZGF0ZShpbnB1dCwgdHMuRmlsZVdhdGNoZXJFdmVudEtpbmQuRGVsZXRlZCk7XG4gICAgICAgICAgICB9XG4gICAgICAgIH1cbiAgICAgICAgZm9yIChjb25zdCBpbnB1dCBvZiBjcmVhdGlvbnMpIHtcbiAgICAgICAgICAgIHdvcmtlci5pbnZhbGlkYXRlKGlucHV0LCB0cy5GaWxlV2F0Y2hlckV2ZW50S2luZC5DcmVhdGVkKTtcbiAgICAgICAgfVxuICAgICAgICBmb3IgKGNvbnN0IGlucHV0IG9mIGNoYW5nZXMpIHtcbiAgICAgICAgICAgIHdvcmtlci5pbnZhbGlkYXRlKGlucHV0LCB0cy5GaWxlV2F0Y2hlckV2ZW50S2luZC5DaGFuZ2VkKTtcbiAgICAgICAgfVxuICAgICAgICB0aW1pbmdFbmQoJ2ludmFsaWRhdGUnKTtcbiAgICAgICAgdGltaW5nU3RhcnQoJ2ZsdXNoV2F0Y2hFdmVudHMnKTtcbiAgICAgICAgd29ya2VyLmZsdXNoV2F0Y2hFdmVudHMoKTtcbiAgICAgICAgdGltaW5nRW5kKCdmbHVzaFdhdGNoRXZlbnRzJyk7XG4gICAgfVxuICAgIHRpbWluZ1N0YXJ0KCdnZXRQcm9ncmFtJyk7XG4gICAgY29uc3QgcHJvZ3JhbSA9IHdvcmtlci5wcm9ncmFtLmdldFByb2dyYW0oKTtcbiAgICB0aW1pbmdFbmQoJ2dldFByb2dyYW0nKTtcbiAgICB0aW1pbmdTdGFydCgnZW1pdCcpO1xuICAgIGNvbnN0IHJlc3VsdCA9IHByb2dyYW0uZW1pdCh1bmRlZmluZWQsIHVuZGVmaW5lZCwgY2FuY2VsbGF0aW9uVG9rZW4pO1xuICAgIHRpbWluZ0VuZCgnZW1pdCcpO1xuICAgIHRpbWluZ1N0YXJ0KCdkaWFnbm9zdGljcycpO1xuICAgIGNvbnN0IGRpYWdub3N0aWNzID0gdHMuZ2V0UHJlRW1pdERpYWdub3N0aWNzKHByb2dyYW0sIHVuZGVmaW5lZCwgY2FuY2VsbGF0aW9uVG9rZW4pLmNvbmNhdChyZXN1bHQ/LmRpYWdub3N0aWNzKTtcbiAgICB0aW1pbmdFbmQoJ2RpYWdub3N0aWNzJyk7XG4gICAgY29uc3Qgc3VjY2VkZWQgPSBkaWFnbm9zdGljcy5sZW5ndGggPT09IDA7XG4gICAgaWYgKCFzdWNjZWRlZCkge1xuICAgICAgICByZXF1ZXN0Lm91dHB1dC53cml0ZSh3b3JrZXIuZm9ybWF0RGlhZ25vc3RpY3MoZGlhZ25vc3RpY3MpKTtcbiAgICAgICAgaXNWZXJib3NlKCkgJiYgd29ya2VyLnByaW50RlNUcmVlKCk7XG4gICAgfVxuICAgIC8vIEB0cy1leHBlY3QtZXJyb3JcbiAgICBpZiAodHMucGVyZm9ybWFuY2UgJiYgdHMucGVyZm9ybWFuY2UuaXNFbmFibGVkKCkpIHtcbiAgICAgICAgLy8gQHRzLWV4cGVjdC1lcnJvclxuICAgICAgICB0cy5wZXJmb3JtYW5jZS5mb3JFYWNoTWVhc3VyZSgobmFtZSwgZHVyYXRpb24pID0+IHJlcXVlc3Qub3V0cHV0LndyaXRlKGAke25hbWV9IHRpbWU6ICR7ZHVyYXRpb259XFxuYCkpO1xuICAgIH1cbiAgICB3b3JrZXIucHJldmlvdXNJbnB1dHMgPSBpbnB1dHM7XG4gICAgd29ya2VyLnBvc3RSdW4oKTtcbiAgICBkZWJ1ZyhgIyBGaW5pc2hlZCB0aGUgd29ya2ApO1xuICAgIHJldHVybiBzdWNjZWRlZCA/IDAgOiAxO1xufVxuaWYgKHJlcXVpcmUubWFpbiA9PT0gbW9kdWxlICYmIHdvcmtlcl9wcm90b2NvbC5pc1BlcnNpc3RlbnRXb3JrZXIocHJvY2Vzcy5hcmd2KSkge1xuICAgIGNvbnNvbGUuZXJyb3IoYFJ1bm5pbmcgJHtNTkVNT05JQ30gYXMgYSBCYXplbCB3b3JrZXJgKTtcbiAgICBjb25zb2xlLmVycm9yKGBUeXBlU2NyaXB0IHZlcnNpb246ICR7dHMudmVyc2lvbn1gKTtcbiAgICB3b3JrZXJfcHJvdG9jb2wuZW50ZXJXb3JrZXJMb29wKGVtaXQpO1xufVxuZWxzZSBpZiAocmVxdWlyZS5tYWluID09PSBtb2R1bGUpIHtcbiAgICBpZiAoIXByb2Nlc3MuY3dkKCkuaW5jbHVkZXMoXCJzYW5kYm94XCIpKSB7XG4gICAgICAgIGNvbnNvbGUuZXJyb3IoYFdBUk5JTkc6IFJ1bm5pbmcgJHtNTkVNT05JQ30gYXMgYSBzdGFuZGFsb25lIHByb2Nlc3NgKTtcbiAgICAgICAgY29uc29sZS5lcnJvcihgU3RhcnRlZCBhIHN0YW5kYWxvbmUgcHJvY2VzcyB0byBwZXJmb3JtIHRoaXMgYWN0aW9uIGJ1dCB0aGlzIG1pZ2h0IGxlYWQgdG8gc29tZSB1bmV4cGVjdGVkIGJlaGF2aW9yIHdpdGggdHNjIGR1ZSB0byBiZWluZyBydW4gbm9uLXNhbmRib3hlZC5gKTtcbiAgICAgICAgY29uc29sZS5lcnJvcihgWW91ciBidWlsZCBtaWdodCBiZSBtaXNjb25maWd1cmVkLCB0cnkgcHV0dGluZyBcImJ1aWxkIC0tc3RyYXRlZ3k9JHtNTkVNT05JQ309d29ya2VyXCIgaW50byB5b3VyIC5iYXplbHJjIG9yIGFkZCBcInN1cHBvcnRzX3dvcmtlcnMgPSBGYWxzZVwiIGF0dHJpYnV0ZSBpbnRvIHRoaXMgdHNfcHJvamVjdCB0YXJnZXQuYCk7XG4gICAgfVxuICAgIGZ1bmN0aW9uIGV4ZWN1dGVDb21tYW5kTGluZSgpIHtcbiAgICAgICAgLy8gd2lsbCBleGVjdXRlIHRzYy5cbiAgICAgICAgcmVxdWlyZShcInR5cGVzY3JpcHQvbGliL3RzY1wiKTtcbiAgICB9XG4gICAgLy8gbmV3ZXIgdmVyc2lvbnMgb2YgdHlwZXNjcmlwdCBleHBvc2VzIGV4ZWN1dGVDb21tYW5kTGluZSBmdW5jdGlvbiB3ZSB3aWxsIHByZWZlciB0byB1c2UuIFxuICAgIC8vIGlmIGl0J3MgbWlzc2luZywgZHVlIHRvIG9sZGVyIHZlcnNpb24gb2YgdHlwZXNjcmlwdCwgd2UnbGwgdXNlIG91ciBpbXBsZW1lbnRhdGlvbiB3aGljaCBjYWxscyB0c2MuanMgYnkgcmVxdWlyaW5nIGl0LlxuICAgIC8vIEB0cy1leHBlY3QtZXJyb3JcbiAgICBjb25zdCBleGVjdXRlID0gdHMuZXhlY3V0ZUNvbW1hbmRMaW5lIHx8IGV4ZWN1dGVDb21tYW5kTGluZTtcbiAgICBsZXQgcCA9IHByb2Nlc3MuYXJndltwcm9jZXNzLmFyZ3YubGVuZ3RoIC0gMV07XG4gICAgaWYgKHAuc3RhcnRzV2l0aCgnQCcpKSB7XG4gICAgICAgIC8vIHAgaXMgcmVsYXRpdmUgdG8gZXhlY3Jvb3QgYnV0IHdlIGFyZSBpbiBiYXplbC1vdXQgc28gd2UgaGF2ZSB0byBnbyB0aHJlZSB0aW1lcyB1cCB0byByZWFjaCBleGVjcm9vdC5cbiAgICAgICAgLy8gcCA9IGJhemVsLW91dC9kYXJ3aW5fYXJtNjQtZmFzdGJ1aWxkL2Jpbi8wLnBhcmFtc1xuICAgICAgICAvLyBjdXJyZW50RGlyID0gIGJhemVsLW91dC9kYXJ3aW5fYXJtNjQtZmFzdGJ1aWxkL2JpblxuICAgICAgICBwID0gcGF0aC5yZXNvbHZlKCcuLicsICcuLicsICcuLicsIHAuc2xpY2UoMSkpO1xuICAgIH1cbiAgICBjb25zdCBhcmdzID0gZnMucmVhZEZpbGVTeW5jKHApLnRvU3RyaW5nKCkudHJpbSgpLnNwbGl0KCdcXG4nKTtcbiAgICB0cy5zeXMuYXJncyA9IHByb2Nlc3MuYXJndiA9IFtwcm9jZXNzLmFyZ3YwLCBwcm9jZXNzLmFyZ3ZbMV0sIC4uLmFyZ3NdO1xuICAgIGV4ZWN1dGUodHMuc3lzLCBub29wLCBhcmdzKTtcbn1cbmV4cG9ydCBjb25zdCBfX2RvX25vdF91c2VfdGVzdF9vbmx5X18gPSB7IGNyZWF0ZUZpbGVzeXN0ZW1UcmVlOiBjcmVhdGVGaWxlc3lzdGVtVHJlZSwgZW1pdDogZW1pdCwgd29ya2VyczogdGVzdE9ubHlHZXRXb3JrZXJzKCkgfTtcbi8vIyBzb3VyY2VNYXBwaW5nVVJMPWVudHJ5cG9pbnQuanMubWFwIl0sIm5hbWVzIjpbInBhdGgiLCJmcyIsInY4IiwidHMiXSwibWFwcGluZ3MiOiI7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O0FBQUEsSUFBSSxPQUFPLEdBQUcsS0FBSyxDQUFDO0FBQ2IsU0FBUyxLQUFLLENBQUMsR0FBRyxJQUFJLEVBQUU7QUFDL0IsSUFBSSxPQUFPLElBQUksT0FBTyxDQUFDLEtBQUssQ0FBQyxHQUFHLElBQUksQ0FBQyxDQUFDO0FBQ3RDLENBQUM7QUFDTSxTQUFTLFlBQVksQ0FBQyxLQUFLLEVBQUU7QUFDcEM7QUFDQTtBQUNBLElBQUksT0FBTyxHQUFHLEtBQUssR0FBRyxDQUFDLENBQUM7QUFDeEIsQ0FBQztBQUNNLFNBQVMsU0FBUyxHQUFHO0FBQzVCLElBQUksT0FBTyxPQUFPLENBQUM7QUFDbkI7O0FDVk8sU0FBUyxjQUFjLENBQUMsSUFBSSxFQUFFLE1BQU0sRUFBRSxVQUFVLEVBQUU7QUFDekQsSUFBSSxPQUFPLENBQUMsR0FBRyxJQUFJLEtBQUs7QUFDeEIsUUFBUSxJQUFJLE1BQU0sRUFBRTtBQUNwQixZQUFZLE1BQU0sSUFBSSxLQUFLLENBQUMsQ0FBQyxTQUFT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
