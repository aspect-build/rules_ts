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
            const subnodes = Object.keys(node).sort((a, b) => node[a][Type] - node[b][Type]);
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
        debug(output.join("\n"));
    }

    function getNode(p) {
        const segments = p.split(path.sep);
        let node = tree;
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            if (!(segment in node)) {
                return undefined;
            }
            node = node[segment];
            if (node[Type] == TYPE.SYMLINK) {
                node = getNode(node[Symlink]);
                // dangling symlink; symlinks point to a non-existing path.
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
        const segments = p.split(path.sep);
        const trail = [];
        let node = tree;
        for (let i = 0; i < segments.length; i++) {
            const segment = segments[i];
 
            if (node && node[Type] == TYPE.SYMLINK) {
                // stop; this is possibly path to a symlink which points to a treeartifact.
                //// version 6.0.0 has a weird behavior where it expands symlinks that point to treeartifact when --experimental_undeclared_symlink is turned off.
                debug(`WEIRD_BAZEL_6_BEHAVIOR: stopping at ${trail.join(path.sep)}`)
                return;
            }

            const currentp = path.join(...trail, segment);

            if (typeof node[segment] != "object") {
                const possiblyResolvedSymlinkPath = followSymlinkUsingRealFs(currentp)
                if (possiblyResolvedSymlinkPath != currentp) {
                    node[segment] = {
                        [Type]: TYPE.SYMLINK,
                        [Symlink]: possiblyResolvedSymlinkPath
                    }
                    notifyWatchers(trail, segment, TYPE.SYMLINK, EVENT_TYPE.ADDED);
                    return;
                } 

                // last of the segments; which assumed to be a file
                if (i == segments.length-1) {
                    node[segment] = { [Type]: TYPE.FILE };
                    notifyWatchers(trail, segment, TYPE.FILE, EVENT_TYPE.ADDED);
                } else {
                    node[segment] = { [Type]: TYPE.DIR };
                    notifyWatchers(trail, segment, TYPE.DIR, EVENT_TYPE.ADDED);
                }
            }
            node = node[segment];
            trail.push(segment);
        }
    }

    function remove(p) {
        const segments = p.split(path.sep).filter(seg => seg != "");
        let node = {
            parent: undefined, 
            segment: undefined, 
            current: tree
        };
        for (let i = 0; i < segments.length; i++) {
            const segment = segments[i];
            if (node.current[Type] == TYPE.SYMLINK) {
                debug(`WEIRD_BAZEL_6_BEHAVIOR: removing ${p} starting from the symlink parent since it's a node with a parent that is a symlink.`)
                segments.splice(i) // remove rest of the elements starting from i which comes right after symlink segment.
                break;
            }
            const current = node.current[segment];
            if (!current) {
                // It is not likely to end up here unless fstree does something undesired. 
                // we will soft fail here due to regression in bazel 6.∂
                debug(`remove: could not find ${p}`);
                return;
            }
            node = {
                parent: node, 
                segment: segment, 
                current: current 
            }
        }

        // parent path of current path(p)
        const parentSegments = segments.slice(0, -1);

        // remove current node using parent node
        delete node.parent.current[node.segment];
        notifyWatchers(parentSegments, node.segment, node.current[Type], EVENT_TYPE.REMOVED)

        // start traversing from parent of last segment
        let removal = node.parent;
        let parents = [...parentSegments]
        while(removal.parent) {
            const keys = Object.keys(removal.current);
            if (keys.length > 0) {
                // if current node has subnodes, DIR, FILE, SYMLINK etc, then stop traversing up as we reached a parent node that has subnodes. 
                break;
            }

            // walk one segment up/parent to avoid calling slice for notifyWatchers. 
            parents.pop();

            if (removal.current[Type] == TYPE.DIR) {
                // current node has no children. remove current node using its parent node
                delete removal.parent.current[removal.segment];
                notifyWatchers(parents, removal.segment, TYPE.DIR, EVENT_TYPE.REMOVED)
            }

            // traverse up
            removal = removal.parent;
        }
    }

    function update(p) {
        const segments = p.split(path.sep);
        const parent = [];
        let node = tree;
        for (const segment of segments) {
            if (!segment) {
                continue;
            }
            parent.push(segment);
            const currentp = parent.join(path.sep);

            if (!node[segment]) {
                debug(`WEIRD_BAZEL_6_BEHAVIOR: can't walk down the path ${p} from ${currentp} inside ${segment}`);
                // bazel 6 + --noexperimental_allow_unresolved_symlinks: has a weird behavior where bazel will won't report symlink changes but 
                // rather reports changes in the treeartifact that symlink points to. even if symlink points to somewhere new. :(
                // since `remove` removed this node previously,  we just need to call add to create necessary nodes.
                // see: no_undeclared_symlink_tests.bats for test cases
                return add(p);
            }

            node = node[segment];

            if (node[Type] == TYPE.SYMLINK) {
                const newSymlinkPath = followSymlinkUsingRealFs(currentp);
                if (newSymlinkPath == currentp) {
                    // not a symlink anymore.
                    debug(`${currentp} is no longer a symlink since ${currentp} == ${newSymlinkPath}`)
                    node[Type] = TYPE.FILE;
                    delete node[Symlink];
                } else if (node[Symlink] != newSymlinkPath) {
                    debug(`updating symlink ${currentp} from ${node[Symlink]} to ${newSymlinkPath}`)
                    node[Symlink] = newSymlinkPath;
                }
                notifyWatchers(parent, segment, node[Type], EVENT_TYPE.UPDATED);
                return; // return the loop as we don't anything to be symlinks from on;
            }
        }
        // did not encounter any symlinks along the way. it's a DIR or FILE at this point.
        const basename = parent.pop();
        notifyWatchers(parent, basename, node[Type], EVENT_TYPE.UPDATED);
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
        const segments = p.split(path.sep);
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
            currentPath = path.join(currentPath, segment);
            if (node[Type] == TYPE.SYMLINK) {
                currentPath = node[Symlink];
                node = getNode(node[Symlink]);
                // dangling symlink; symlinks point to a non-existing path. can't follow it
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

    function notifyWatchers(trail, segment, type, eventType) {
        const final = [...trail, segment];
        const finalPath = final.join(path.sep);
        if (type == TYPE.FILE) {
            // notify file watchers watching at the file path, excluding recursive ones. 
            // TODO: file watchers shouldn't have the recursive option. this is wrong.
            notifyWatcher(final, finalPath, eventType, false);
            // notify directory watchers watching at the parent of the file, including the recursive directory watchers at parent.
            notifyWatcher(trail, finalPath, eventType);
        } else {
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
        while(parent.length) {
            parent.pop();
            // invoke only recursive watchers
            notifyWatcher(parent, finalPath, eventType, true);
        }
    }

    function notifyWatcher(parent, path, eventType, recursive = undefined) {
        let node = getWatcherNode(parent);
        if (typeof node == "object" && Watcher in node) {
            for (const watcher of node[Watcher]) {
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

    function watchFile(p, callback) {
        return watch(p, callback)
    }

    return { add, remove, update, notify, fileExists, directoryExists, isSymlink, realpath, readDirectory, getDirectories, watchDirectory: watch, watchFile: watchFile, printTree }
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
                    debug(`createEmitAndLibCacheAndDiagnosticsProgram: deleting ${sourcePath} as it's no longer a src.`);
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
    if (!compilerOptions.sourceRoot) {
        compilerOptions.sourceRoot = compilerOptions.rootDir
    }
    compilerOptions.mapRoot = path.join("__synthetic__outdir__", compilerOptions.outDir)

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
            const rewrite = p.replace("__synthetic__outdir__", ".")
            debug("writeFile", p, rewrite);
            ts.sys.writeFile(rewrite, data, mark);
        },
        resolvePath: (p) => {throw "err: not implemented"},
        realpath: filesystemTree.realpath,
        fileExists: filesystemTree.fileExists,
        directoryExists: filesystemTree.directoryExists,
        getDirectories: filesystemTree.getDirectories,
        watchFile: watchFile,
        watchDirectory: watchDirectory,
        getCurrentDirectory: () => {
            return "/" + cfg
        },
        getExecutingFilePath: () => "/"+executingFilePath,
        exit: exit
    };
    const sys = {
        ...ts.sys,
        ...strictSys,
    };

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


    enableStatisticsAndTracing();
    updateOutputs();

    const program = ts.createWatchProgram(host);

    return { program, checkAndApplyArgs, setOutput, formatDiagnostics, flushWatchEvents, invalidate, postRun, printFSTree: () => filesystemTree.printTree() };


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
        debug(`invalidate ${filePath} : ${ts.FileWatcherEventKind[kind]}`);
        if (kind === ts.FileWatcherEventKind.Deleted) {
            filesystemTree.remove(filePath);
        } else if (kind === ts.FileWatcherEventKind.Created) {
            filesystemTree.add(filePath);
        } else {
            filesystemTree.update(filePath);
        }
        // if (filePath.indexOf("node_modules") != -1 && filesystemTree.isSymlink(filePath) && kind === ts.FileWatcherEventKind.Created) {
        //     const expandedInputs = filesystemTree.readDirectory(filePath, undefined, undefined, undefined, Infinity);
        //     for (const input of expandedInputs) {
        //         filesystemTree.notify(input);
        //     }
        // }
    }

    function enableStatisticsAndTracing() {
        if (compilerOptions.diagnostics || compilerOptions.extendedDiagnostics) {
            ts.performance.enable();
        }
        // tracing is only available in 4.1 and above
        // See: https://github.com/microsoft/TypeScript/wiki/Performance-Tracing
        if (compilerOptions.generateTrace && ts.startTracing && !ts.tracing) {
            ts.startTracing('build', compilerOptions.generateTrace);
        }
    }

    function disableStatisticsAndTracing() {
        ts.performance.disable();
        if (!ts.tracing && ts.startTracing) {
            ts.tracing.stopTracing()
        }
    }

    function postRun( ) {
        if (ts.performance && ts.performance.isEnabled()) {
            ts.performance.forEachMeasure((name, duration) => write(`${name} time: ${duration}\n`));
            ts.performance.disable()
            ts.performance.enable()
        }
    
        if (ts.tracing) {
            ts.tracing.stopTracing()
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
            debug(`arguments have changed.`);
            debug(`  current: ${newArgs.join(" ")}`);
            debug(`  previous: ${args.join(" ")}`);
         
            const {options} = ts.parseCommandLine(newArgs);
            for (const key in compilerOptions) {
                if (!(key in options)) {
                    delete compilerOptions[key];
                }
            }
            for (const key in options) {
                compilerOptions[key] = options[key];
            }
  
            disableStatisticsAndTracing();
            enableStatisticsAndTracing();
            updateOutputs();
            // invalidating tsconfig will cause parseConfigFile to be invoked
            filesystemTree.update(tsconfig);
            args = newArgs;
        }
    }

    function readFile(filePath, encoding) {
        filePath = path.resolve(sys.getCurrentDirectory(), filePath)

        //external lib are transitive sources thus not listed in the inputs map reported by bazel.
        if (!filesystemTree.fileExists(filePath) && !isExternalLib(filePath) && !outputs.has(filePath)) {
            output.write(`tsc tried to read file (${filePath}) that wasn't an input to it.` + "\n");
            //throw new Error(`tsc tried to read file (${filePath}) that wasn't an input to it.`);
        }

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
    worker.postRun();

    debug(`# Finished the work`);
    return succeded ? 0 : 1;
}


if (require.main === module && worker_protocol.isPersistentWorker(process.argv)) {
    console.error(`Running ${MNEMONIC} as a Bazel worker`);
    console.error(`TypeScript version: ${ts.version}`);
    worker_protocol.enterWorkerLoop(emit);
} else if (require.main === module) {
    if (!process.cwd().includes("sandbox")) {
        console.error(`WARNING: Running ${MNEMONIC} as a standalone process`);
        console.error(
            `Started a standalone process to perform this action but this might lead to some unexpected behavior with tsc due to being run non-sandboxed.`
        );
        console.error(
            `Your build might be misconfigured, try putting "build --strategy=${MNEMONIC}=worker" into your .bazelrc or add "supports_workers = False" attribute into this ts_project target.`
        );
    }

    function executeCommandLine() {
        // will execute tsc.
        require("typescript/lib/tsc");
    }

    // newer versions of typescript exposes executeCommandLine function we will prefer to use. 
    // if it's missing, due to older version of typescript, we'll use our implementation which calls tsc.js by requiring it.
    const execute = ts.executeCommandLine || executeCommandLine;
    let p = process.argv[process.argv.length - 1];
    if (p.startsWith('@')) {
        // p is relative to execroot but we are in bazel-out so we have to go three times up to reach execroot.
        // p = bazel-out/darwin_arm64-fastbuild/bin/0.params
        // currentDir =  bazel-out/darwin_arm64-fastbuild/bin
        p = path.resolve('..', '..', '..', p.slice(1));
    }
    const args = fs.readFileSync(p).toString().trim().split('\n');
    ts.sys.args = process.argv = [process.argv0, process.argv[1], ...args];
    execute(ts.sys, ts.noop, args);
}

module.exports.__do_not_use_test_only__ = {createFilesystemTree: createFilesystemTree, emit: emit, workers: workers};
