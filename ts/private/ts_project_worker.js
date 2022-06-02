const fs = require('fs')
const ts = require('typescript')
const path = require('path')
const worker = require('@bazel/worker')
const MNEMONIC = 'TsProject'

function noop() { }

function debuglog(...args) {
    false && worker.log(...args)
}

/** Timing */
const timing = {}
function timingStart(label) {
    timing[label] = performance.now();
}
function timingEnd(label) {
    debuglog(`${label} ${performance.now() - timing[label]}ms`)
}


function getArgsFromParamFile() {
    let paramFilePath = process.argv.pop()
    if (paramFilePath.startsWith('@')) {
        paramFilePath = paramFilePath.slice(1)
    }
    return fs.readFileSync(paramFilePath).toString().split('\n')
}



// TODO: support overloading with https://github.com/microsoft/TypeScript/blob/ab2523bbe0352d4486f67b73473d2143ad64d03d/src/compiler/builder.ts#L1008
function createEmitCacheAndDiagnosticsProgram(rootNames, options, host, oldProgram, configFileParsingDiagnostics, projectReferences) {
    const builder = ts.createEmitAndSemanticDiagnosticsBuilderProgram(rootNames, options, host, oldProgram, configFileParsingDiagnostics, projectReferences);
    /** @type {Map} */
    const emittedFiles = host.emittedFiles = host.emittedFiles || new Map();
    /** @type {Map} */
    const emittingMap = host.emittedFilesWeak = host.emittedFilesWeak || new Map();

    const emit = builder.emit;
    builder.emit = (targetSourceFile, writeFile, cancellationToken, emitOnlyDtsFiles, customTransformers) => {
        writeFile = writeFile || host.writeFile
        if (!targetSourceFile) {
            for (const [path, content] of emittedFiles.entries()) {
                const sourcePath = emittingMap.get(path);
                if(!builder.getSourceFile(sourcePath)) {
                    debuglog(`removing ${path} from emit cache`);
                    emittedFiles.delete(path);
                    emittingMap.delete(path);
                } else {
                    writeFile(path, content);
                }
            }
        }

        const writeF = (fileName, data, writeByteOrderMark, onError, sourceFiles) => {
            writeFile(fileName, data, writeByteOrderMark, onError, sourceFiles);
            emittingMap.set(fileName, sourceFiles[0].fileName)
            emittedFiles.set(fileName, data)
        }
        return emit(targetSourceFile, writeF, cancellationToken, emitOnlyDtsFiles, customTransformers)
    }

    return builder;
}

/** @type {ts.FormatDiagnosticsHost} */
const formatDiagnosticHost = {
    getCanonicalFileName: (path) => path,
    getCurrentDirectory: ts.sys.getCurrentDirectory,
    getNewLine: () => ts.sys.newLine,
}

function printDiagnostics(diagnostics) {
    worker.log('')
    worker.log(ts.formatDiagnostics(diagnostics, formatDiagnosticHost))
}



function isAncestorDirectory(ancestor, child) {
    const ancestorChunks = ancestor.split(path.sep).filter(i => !!i);
    const childChunks = child.split(path.sep).filter(i => !!i);
    return ancestorChunks.every((chunk, i) => childChunks[i] === chunk)
}

/** @type {Map<string, {program: ts.EmitAndSemanticDiagnosticsBuilderProgram, host: ts.WatchCompilerHost, previousInputs?: import("@bazel/worker").Inputs}>} */
const workers = new Map(); 

function getTsConfigPath(args) {
    return args[args.indexOf('--project') + 1]
}

function createProgram(args, initialInputs) {
    const tsconfig = getTsConfigPath(args);
    const startingDir = path.dirname(tsconfig)
    const absStartingDir = path.join(process.cwd(), startingDir);
    const execRoot = path.resolve(process.cwd(), '..', '..', '..')

    debuglog(`tsconfig: ${tsconfig}`);
    debuglog(`starting_dir: ${startingDir}`);
    debuglog(`execroot ${execRoot}`);

    const parsedArgs = ts.parseCommandLine(args)

    const directoryWatchers = new Map();
    const fileWatchers = new Map();

    const knownInputs = new Set(initialInputs);

    /** @type {ts.System} */
    const sys = {
        ...ts.sys,
        write: worker.log,
        writeOutputIsTTY: false,
        setTimeout: setImmediate,
        clearTimeout: clearImmediate,
        fileExists: fileExists,
        readFile: readFile,
        writeFile: writeFile,
        readDirectory: readDirectory,
        directoryExists: directoryExists,
        getDirectories: getDirectories,
        watchFile: watchFile,
        watchDirectory: watchDirectory
    }

    const host = ts.createWatchCompilerHost(
        tsconfig,
        parsedArgs.options,
        sys,
        createEmitCacheAndDiagnosticsProgram,
        noop,
        noop
    )

    host.invalidate = invalidate;

    program = ts.createWatchProgram(host)
    

    function getDirectoryWatcherForPath(path) {
        for (const [directory, cb] of directoryWatchers.entries()) {
            if (isAncestorDirectory(directory, path)) {
                debuglog(`found a directory watcher for ${path} ${directory}`)
                return cb;
            }
        }
    }

    function writeFile(path, data, writeByteOrderMark) {
        debuglog(`writeFile ${path}`);
        ts.sys.writeFile(path, data, writeByteOrderMark);
    }

    function readFile(filePath, encoding) {
        debuglog(`readFile ${filePath}`);
        const relative = path.relative(execRoot, filePath)
        /** if it is under node_modules just allow file reads as we don't have a list of deps */
        if (filePath.indexOf("node_modules") == -1 && !knownInputs.has(relative)) {
            return undefined
        }
        return ts.sys.readFile(filePath, encoding);
    }

    function directoryExists(directory) {
        if (!directory.startsWith(execRoot)) {
            return false;
        }
        const exists = ts.sys.directoryExists(directory)
        debuglog(`directoryExists ${directory} ${exists}`);
        return exists
    }

    function getDirectories(directory) {
        const dirs = ts.sys.getDirectories(directory);
        debuglog(`getDirectories ${directory}`, dirs)
        return dirs;
    }

    function fileExists(filePath) {
        const relative = path.relative(execRoot, filePath)
        debuglog(`fileExists ${filePath} ${knownInputs.has(relative)}`)
        if (!knownInputs.has(relative)) {
            return false;
        }
        return true;
    }

    function readDirectory(directory, extensions, exclude, include, depth) {
        const files = ts.sys.readDirectory(directory, extensions, exclude, include, depth);
        // TODO: walk up the directory to find a tsconfig.json to determine whether we are trying to read a directory
        // that belongs to a upstream target.
        const strictView = [];
        if (directory != absStartingDir) {
            for (const file of files) {
                // tsc should never read source files of upstream targets.
                if (file.endsWith(".d.ts") || file.endsWith(".js")) {
                    const relative = path.relative(execRoot, file)
                    if (knownInputs.has(relative)) {
                        strictView.push(file);
                    }
                } else if (file.endsWith(".ts")) {
                    
                } else {
                    strictView.push(file);
                }
            }
        } else {
            for (const file of files) {
                const relativePath = path.relative(execRoot, file);
                if (knownInputs.has(relativePath)) {
                    strictView.push(file);
                } else {
                    debuglog(`Skipping ${relativePath} as it is not input to current compilation.`)
                }
            }
        }

        debuglog(`readDirectory ${directory} ${strictView}`)

        return strictView;
    }

    function invalidate(filePath, kind) {
        if (filePath.endsWith(".params")) return;
        debuglog(`invalidate ${filePath} : ${ts.FileWatcherEventKind[kind]}`)
        if (kind == ts.FileWatcherEventKind.Created) { 
            knownInputs.add(filePath);
            // signal that the directory has been created.
            const dirname = path.dirname(filePath);
            getDirectoryWatcherForPath(filePath)?.(dirname);
        } else if (kind == ts.FileWatcherEventKind.Deleted) {
            knownInputs.delete(filePath);
        }

        let callback = fileWatchers.get(filePath)

        callback?.(kind)

        if (!callback) {
            debuglog(`no callback for ${filePath}`);
        }

        // in case this file was never seen before then we have to report it through
        // ancestor file watcher. Usually happens when a new file is introduced
        if (!callback) {
            debuglog(`looking for callback ${filePath}`)
            getDirectoryWatcherForPath(filePath)?.(filePath);
        }
    }

    function watchDirectory(directoryPath, callback, recursive, options) {
        directoryPath = path.relative(execRoot, directoryPath)
        // since rules_js runs everything under bazel-out we shouldn't care about anything outside of it.
        if (!directoryPath.startsWith("bazel-out")) {
            return;
        }
        debuglog(`watchDirectory ${directoryPath}`)
        directoryWatchers.set(directoryPath, (input) => callback(path.join(execRoot, input)))
        return {
            close: () => {
                directoryWatchers.delete(directoryPath)
                debuglog(`watchDirectory@close ${directoryPath}`)
            } 
        }
    }

    function watchFile(filePath, callback, interval) {
        debuglog(`watchFile ${filePath} ${interval}`)
        const relativeFilePath = path.relative(execRoot, filePath)
        fileWatchers.set(relativeFilePath, (kind) => callback(filePath, kind))
        return { 
            close: () => {
                fileWatchers.delete(relativeFilePath);
                debuglog(`watchFile@close ${filePath}`)
            } 
        }
    }
    return {host, program}
}

function getOrCreateWorker(key, args, inputs) {
    if (!workers.has(key)) {
        debuglog(`Creating a worker for ${key}`);
        const {program, host} = createProgram(args, inputs)
        workers.set(key, {
            program,
            host
        })
    }
    return workers.get(key);
}

async function emit(args, inputs) {
    const key = getTsConfigPath(args);
    const workir = getOrCreateWorker(key, args, Object.keys(inputs));
    const host = workir.host;
    const lastRequestTimestamp = Date.now();
    const previousInputs = workir.previousInputs;

    debuglog(`Performing work for ${key}`);
    
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
        timingEnd("invalidate")
    }

    timingStart("getProgram")
    // NOTE: Always get the program after the invalidation logic above as watcher program could
    // swap the program with new one based on the changes
    const program = workir.program.getProgram()
    timingEnd("getProgram")


    const cancellationToken = {
        isCancellationRequested: function (timestamp) {
            return timestamp !== lastRequestTimestamp
        }.bind(null, lastRequestTimestamp),
        throwIfCancellationRequested: function (timestamp) {
            if (timestamp !== lastRequestTimestamp) {
                throw new ts.OperationCanceledException()
            }
        }.bind(null, lastRequestTimestamp),
    }

    timingStart("emit")
    const result = program.emit(undefined, undefined, cancellationToken)
    timingEnd("emit")

    timingStart("diagnostics")
    const diagnostics = ts.getPreEmitDiagnostics(
        program,
        undefined,
        cancellationToken
    ).concat(result?.diagnostics)
    timingEnd("diagnostics")

    const succeded =
        !result.emitSkipped &&
        result?.diagnostics.length === 0 &&
        diagnostics.length == 0


    if (!succeded) {
        printDiagnostics(diagnostics)    
    }
    
    workir.previousInputs = inputs;

    return succeded
}

function emitOnce(args) {
    const cmdline = ts.parseCommandLine(args)
    const program = ts.createProgram({
        options: cmdline.options,
        rootNames: cmdline.fileNames,
        projectReferences: cmdline.projectReferences,
        configFileParsingDiagnostics: cmdline.errors
    });
    const result = program.emit();
    const diagnostics = ts.getPreEmitDiagnostics(program)
    const succeded =
        !result.emitSkipped &&
        result?.diagnostics.length === 0 &&
        diagnostics.length == 0

    if (!succeded) {
        printDiagnostics(diagnostics)
    }

    return succeded
}

function main() {
    if (worker.runAsWorker(process.argv)) {
        worker.log(`Running ${MNEMONIC} as a Bazel worker`)
        worker.runWorkerLoop(emit)
    } else {
        worker.log(`Running ${MNEMONIC} as a standalone process`)
        worker.log(`Started a new process to perform this action. Your build might be misconfigured, try \n build --strategy=${MNEMONIC}=worker`)
        const args = getArgsFromParamFile()
        if (!emitOnce(args)) {
            process.exit(1)
        }
    }
}

if (require.main === module) {
    main()
}
