const fs = require('fs')
const ts = require('typescript')
const path = require('path')
const worker = require('@bazel/worker')
const MNEMONIC = 'TsProject'

const console = new globalThis.console.Console(process.stderr, process.stderr)

function noop() { }

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
    const emittedFiles = host.emittedFiles = host.emittedFiles || new Map();
    const emit = builder.emit;
    builder.emit = (targetSourceFile, writeFile, cancellationToken, emitOnlyDtsFiles, customTransformers) => {
        writeFile = writeFile || host.writeFile
        for (const [path, content] of emittedFiles) {
            writeFile(path, content)
        }
        const writeF = (fileName, data, writeByteOrderMark, onError, sourceFiles) => {
            writeFile(fileName, data, writeByteOrderMark, onError, sourceFiles);
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

/** @type {Date} */
let lastRequestTimestamp
/** @type {string} */
let lastRequestArgHash
/** @type {ts.WatchOfConfigFile<ts.EmitAndSemanticDiagnosticsBuilderProgram>} */
let program

let host

/** @type {import("@bazel/worker").Inputs} */
let previousInputs


function getProgram(args, initialInputs) {
    if (lastRequestArgHash !== args.join(' ')) {
        program = lastRequestArgHash = host = undefined
    }

    if (!program) {
        lastRequestArgHash = args.join(' ')

        const startingDir = process.cwd();
        const execRoot = path.resolve(startingDir, '..', '..', '..')

        const tsconfigPath = args[args.indexOf('--project') + 1]
        worker.log(tsconfigPath)
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
            readDirectory: readDirectory,
            clearTimeout: clearImmediate,
            watchFile: watchFile,
            watchDirectory: watchDirectory
        }

        host = ts.createWatchCompilerHost(
            tsconfigPath,
            parsedArgs.options,
            sys,
            createEmitCacheAndDiagnosticsProgram,
            noop,
            noop
        )
        host.invalidate = invalidate;

        program = ts.createWatchProgram(host)

        function readDirectory(directory, extensions, exclude, include, depth) {
            const files = ts.sys.readDirectory(directory, extensions, exclude, include, depth);
            const strictView = [];
  
            const relativeDirectory = path.relative(execRoot, directory);


            // TODO: 
            // - find out why tsc does not pick up upstream declaration changes
            // - only run strictView logic for current directory. tsc should be free to read upstream directories. (limit these to deps attribute.)
            if (relativeDirectory != "bazel-out/darwin_arm64-fastbuild/bin/feature") {
                return files
            }

            for (const file of files) {
                const relativePath = path.relative(execRoot, file);
                if (knownInputs.has(relativePath)) {
                    strictView.push(file);
                    worker.debug(`${relativePath} is not filtered as it is known input.`);
                } else {
                    worker.debug(`Skipping ${relativePath} as it is not input to current compilation.`)
                }
            }
            worker.log(relativeDirectory, files, strictView, knownInputs);

            return strictView;
        }

        function invalidate(filePath, kind) {
            worker.log(`Invalidate:: ${filePath} :: ${ts.FileWatcherEventKind[kind]}`)
            if (kind == ts.FileWatcherEventKind.Created) {
                // we need to report the new file through an ancestor directory watcher
                for (const [directory, callback] of directoryWatchers.entries()) {
                    if (isAncestorDirectory(directory, filePath)) {
                        callback(filePath);
                        break;
                    }
                }
                knownInputs.add(filePath);
            } else {
                fileWatchers.get(filePath)?.(kind)
                if (kind == ts.FileWatcherEventKind.Deleted) {
                    knownInputs.delete(filePath);
                }
            }
        }

        function watchDirectory(directoryPath, callback, recursive, options) {
            worker.log(`watchDirectory ${directoryPath}`)
            const relativeFilePath = path.relative(execRoot, directoryPath)
            // since rules_js runs everything under bazel-out we shouldn't care about anything outside of it.
            if (relativeFilePath.startsWith("bazel-out")) {
                directoryWatchers.set(relativeFilePath, (input) => callback(path.join(execRoot, input)))
            }
            return { close: () => directoryWatchers.delete(relativeFilePath) }
        }

        function watchFile(filePath, callback) {
            worker.log(`watchFile ${filePath}`)
            const relativeFilePath = path.relative(execRoot, filePath)
            fileWatchers.set(relativeFilePath, (kind) => callback(filePath, kind))
            return { close: () => fileWatchers.delete(relativeFilePath) }
        }
    }

    return program
}


async function emit(args, inputs) {
    lastRequestTimestamp = Date.now()

    if (previousInputs) {
        console.time(`invalidate`);
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
        console.timeEnd("invalidate")
    }

    const builder = getProgram(args, Object.keys(inputs))

    console.time("getProgram")
    // NOTE: Always get the program after the invalidation logic above as watcher program could
    // swap the program with new one based on the changes
    const program = builder.getProgram()
    console.timeEnd("getProgram")

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

    console.time("emit")
    const result = program.emit(undefined, undefined, cancellationToken)
    console.timeEnd("emit")
    console.time("diagnostics")
    const diagnostics = ts.getPreEmitDiagnostics(
        program,
        undefined,
        cancellationToken
    )
    console.timeEnd("diagnostics")
    const succeded =
        !result.emitSkipped &&
        result?.diagnostics.length === 0 &&
        diagnostics.length == 0

    if (!succeded) {
        printDiagnostics(diagnostics)
    }

    previousInputs = inputs

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
