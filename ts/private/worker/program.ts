import {debug} from "./debugging";
import {noop, notImplemented} from "./util";
import type {Inputs} from "./types";
import * as path from "node:path";
import * as v8 from "v8";
import type {Writable} from "node:stream"
import * as ts from "typescript"
import { createFilesystemTree } from "./vfs";

const workers = new Map<string, ReturnType<typeof createProgram> & { previousInputs?: Inputs; }>();
const libCache = new Map();
const NOT_FROM_SOURCE = Symbol.for("NOT_FROM_SOURCE")
const NEAR_OOM_ZONE = 20 // How much (%) of memory should be free at all times. 
const SYNTHETIC_OUTDIR = "__st_outdir__"

export function isNearOomZone() {
    const stat = v8.getHeapStatistics();
    const used = (100 / stat.heap_size_limit) * stat.used_heap_size
    return 100 - used < NEAR_OOM_ZONE
}

export function sweepLeastRecentlyUsedWorkers() {
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

export function getOrCreateWorker(args: string[], inputs: Inputs, output: Writable) {
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
        worker = createProgram(args, inputs, output, (exitCode: number) => {
            debug(`worker ${key} has quit prematurely with code ${exitCode}`);
            workers.delete(key);
        });
    } else {
        // NB: removed from the map intentionally. to achieve LRU effect on the workers map.
        workers.delete(key)
    }
    workers.set(key, worker)
    return worker;
}

export function testOnlyGetWorkers() {
    return workers
}


function isExternalLib(path: string) {
    return path.includes('external') &&
        path.includes('typescript@') &&
        path.includes('node_modules/typescript/lib')
}

function createEmitAndLibCacheAndDiagnosticsProgram(
    rootNames: readonly string[],
    options: ts.CompilerOptions,
    host: ts.CompilerHost,
    oldProgram: ts.EmitAndSemanticDiagnosticsBuilderProgram,
    configFileParsingDiagnostics: readonly ts.Diagnostic[],
    projectReferences: readonly ts.ProjectReference[]
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
    const outputSourceMapping: Map<string, string | symbol> = (host["outputSourceMapping"] = host["outputSourceMapping"] || new Map());
    /** @type {Map<string, {text: string, writeByteOrderMark: boolean}>} */
    const outputCache: Map<string, { text: string; writeByteOrderMark: boolean; }> = (host["outputCache"] = host["outputCache"] || new Map());

    const emit = builder.emit;
    builder.emit = (targetSourceFile, writeFile, cancellationToken, emitOnlyDtsFiles, customTransformers) => {
        const write = writeFile || host.writeFile;
        if (!targetSourceFile) {
            for (const [path, entry] of outputCache.entries()) {
                const sourcePath = outputSourceMapping.get(path)!;
                if (sourcePath == NOT_FROM_SOURCE) {
                    write(path, entry.text, entry.writeByteOrderMark);
                    continue;
                } 
                // it a file that has to ties to a source file
                if (sourcePath == NOT_FROM_SOURCE) {
                    continue;
                } else if (!builder.getSourceFile(sourcePath as string)) {
                    // source is not part of the program anymore, so drop the output from the output cache.
                    debug(`createEmitAndLibCacheAndDiagnosticsProgram: deleting ${sourcePath as string} as it's no longer a src.`);
                    outputSourceMapping.delete(path);
                    outputCache.delete(path);
                    continue;
                }
            }
        }

        const writeF: ts.WriteFileCallback = (fileName: string, text: string, writeByteOrderMark, onError, sourceFiles) => {
            write(fileName, text, writeByteOrderMark, onError, sourceFiles);
            outputCache.set(fileName, { text, writeByteOrderMark });
            if (sourceFiles?.length && sourceFiles?.length > 0) {
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
    host.getSourceFile = (fileName: string, languageVersionOrOptions: ts.ScriptTarget | ts.CreateSourceFileOptions, onError?: (message: string) => void, shouldCreateNewSourceFile?: boolean) => {
        if (libCache.has(fileName)) {
            return libCache.get(fileName);
        }
        const sf = getSourceFile(fileName, languageVersionOrOptions, onError, shouldCreateNewSourceFile);
        if (sf && isExternalLib(fileName)) {
            debug(`createEmitAndLibCacheAndDiagnosticsProgram: putting default lib ${fileName} into cache.`)
            libCache.set(fileName, sf);
        }
        return sf;
    }

    return builder;
}

function createProgram(args: string[], inputs: Inputs, output: Writable, exit: (code: number) => void) {
    const cmd = ts.parseCommandLine(args);
    const bin = process.cwd(); // <execroot>/bazel-bin/<cfg>/bin
    const execroot = path.resolve(bin, '..', '..', '..'); // execroot
    const tsconfig = path.relative(execroot, path.resolve(bin, cmd.options.project)); // bazel-bin/<cfg>/bin/<pkg>/<options.project>
    const cfg = path.relative(execroot, bin) // /bazel-bin/<cfg>/bin
    const executingfilepath = path.relative(execroot, require.resolve("typescript")); // /bazel-bin/<opt-cfg>/bin/node_modules/tsc/...

    const filesystem = createFilesystemTree(execroot, inputs);
    const outputs = new Set();
    const watchEventQueue = new Array();
    const watchEventsForSymlinks = new Set<string>();

    const strictSys: Partial<ts.System> = {
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
    const sys: ts.System = { ...ts.sys, ...strictSys };
    const host = ts.createWatchCompilerHost(
        cmd.options.project,
        cmd.options,
        sys,
        createEmitAndLibCacheAndDiagnosticsProgram,
        noop,
        noop
    );
    // deleting this will make tsc to not schedule updates but wait for getProgram to be called to apply updates which is exactly what is needed.
    delete host.setTimeout;
    delete host.clearTimeout;

    const formatDiagnosticHost: ts.FormatDiagnosticsHost = {
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

    const program = ts.createWatchProgram(host);

    // early return to prevent from declaring more variables accidentially. 
    return { program, applyArgs, setOutput, formatDiagnostics, flushWatchEvents, invalidate, postRun, printFSTree: filesystem.printTree };

    function formatDiagnostics(diagnostics: ts.Diagnostic[]) {
        return `\n${ts.formatDiagnostics(diagnostics, formatDiagnosticHost)}\n`
    }

    function setOutput(newOutput: Writable) {
        output = newOutput;
    }

    function write(chunk: string) {
        output.write(chunk);
    }

    function enqueueAdditionalWatchEventsForSymlinks() {
        for (const symlink of watchEventsForSymlinks) {
            const expandedInputs = filesystem.readDirectory(symlink, undefined, undefined, undefined, Infinity);
            for (const input of expandedInputs) {
                filesystem.notify(input)
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

    function invalidate(filePath: string, kind: ts.FileWatcherEventKind) {
        debug(`invalidate ${filePath} : ${ts.FileWatcherEventKind[kind]}`);

        if (kind === ts.FileWatcherEventKind.Changed && filePath == tsconfig) {
            applyChangesForTsConfig(args);
        }

        if (kind === ts.FileWatcherEventKind.Deleted) {
            filesystem.remove(filePath);
        } else if (kind === ts.FileWatcherEventKind.Created) {
            filesystem.add(filePath);
        } else {
            filesystem.update(filePath);
        }
        if (filePath.indexOf("node_modules") != -1 && kind === ts.FileWatcherEventKind.Created) {
            const normalizedFilePath = filesystem.normalizeIfSymlink(filePath)
            if (normalizedFilePath) {
                watchEventsForSymlinks.add(normalizedFilePath);
            }
        }
    }

    function enableStatisticsAndTracing() {
        if (compilerOptions.diagnostics || compilerOptions.extendedDiagnostics || host.optionsToExtend.diagnostics || host.optionsToExtend.extendedDiagnostics) {
            ts["performance"].enable();
        }
        // tracing is only available in 4.1 and above
        // See: https://github.com/microsoft/TypeScript/wiki/Performance-Tracing
        if ((compilerOptions.generateTrace || host.optionsToExtend.generateTrace) && ts["startTracing"] && !ts["tracing"]) {
            ts["startTracing"]('build', compilerOptions.generateTrace || host.optionsToExtend.generateTrace);
        }
    }

    function disableStatisticsAndTracing() {
        ts["performance"].disable();
        if (ts["tracing"]) {
            ts["tracing"].stopTracing()
        }
    }

    function postRun() {
        if (ts["performance"] && ts["performance"].isEnabled()) {
            ts["performance"].disable()
            ts["performance"].enable()
        }

        if (ts["tracing"]) {
            ts["tracing"].stopTracing()
        }
    }

    function updateOutputs() {
        outputs.clear();
        if (host.optionsToExtend.tsBuildInfoFile || compilerOptions.tsBuildInfoFile) {
            const p = path.join(sys.getCurrentDirectory(), host.optionsToExtend.tsBuildInfoFile);
            outputs.add(p);
        }
    }

    function applySyntheticOutPaths() {
        host.optionsToExtend.outDir = `${host.optionsToExtend.outDir}/${SYNTHETIC_OUTDIR}`;
        if (host.optionsToExtend.declarationDir) {
            host.optionsToExtend.declarationDir = `${host.optionsToExtend.declarationDir}/${SYNTHETIC_OUTDIR}`
        }
    }

    function applyArgs(newArgs: string[]) {
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
        const raw = ts.readConfigFile(cmd.options.project, readFile);
        const parsedCommandLine = ts.parseJsonConfigFileContent(raw.config, sys, path.dirname(cmd.options.project));
        return parsedCommandLine.options || {};
    }

    function applyChangesForTsConfig(args: string[]) {
        const cmd = ts.parseCommandLine(args);
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

    function readFile(filePath: string, encoding?: string) {
        filePath = path.resolve(sys.getCurrentDirectory(), filePath)

        //external lib are transitive sources thus not listed in the inputs map reported by bazel.
        if (!filesystem.fileExists(filePath) && !isExternalLib(filePath) && !outputs.has(filePath)) {
            output.write(`tsc tried to read file (${filePath}) that wasn't an input to it.` + "\n");
            throw new Error(`tsc tried to read file (${filePath}) that wasn't an input to it.`);
        }

        return ts.sys.readFile(path.join(execroot, filePath), encoding);
    }

    function createDirectory(p: string) {
        p = p.replace(SYNTHETIC_OUTDIR, "")
        ts.sys.createDirectory(p);
    }

    function writeFile(p: string, data: string, writeByteOrderMark?: boolean) {
        p = p.replace(SYNTHETIC_OUTDIR, "")
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
        ts.sys.writeFile(p, data, writeByteOrderMark);
    }

    function watchDirectory(directoryPath: string, callback: ts.DirectoryWatcherCallback, recursive: boolean, options?: ts.WatchOptions) {
        const close = filesystem.watchDirectory(
            directoryPath,
            (input) => watchEventQueue.push([callback, path.join("/", input)]),
            recursive
        );

        return { close };
    }

    function watchFile(filePath: string, callback: ts.FileWatcherCallback, pollingInterval?: number, options?: ts.WatchOptions) {
        // ideally, all paths should be absolute but sometimes tsc passes relative ones.
        filePath = path.resolve(sys.getCurrentDirectory(), filePath)
        const close = filesystem.watchFile(
            filePath,
            (input, kind) => watchEventQueue.push([callback, path.join("/", input), kind])
        )
        return { close };
    }
}