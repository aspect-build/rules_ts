import { debug, isVerbose, setVerbosity } from "./debugging";
import { getOrCreateWorker, testOnlyGetWorkers } from "./program";
import * as fs from "node:fs";
import * as path from "node:path";
import * as ts from "typescript"
import { noop } from "./util";
import "./patches";
import { createFilesystemTree } from "./vfs";

const worker_protocol = require('./worker');
const MNEMONIC = 'TsProject';

function timingStart(label: string) {
    // @ts-expect-error
    ts.performance.mark(`before${label}`);
}
function timingEnd(label: string) {
    // @ts-expect-error
    ts.performance.mark(`after${label}`);
    // @ts-expect-error
    ts.performance.measure(`${MNEMONIC} ${label}`, `before${label}`, `after${label}`);
}


function createCancellationToken(signal: AbortSignal): ts.CancellationToken {
    return {
        isCancellationRequested: () => signal.aborted,
        throwIfCancellationRequested: () => {
            if (signal.aborted) {
                throw new Error(signal.reason);
            }
        }
    }
}

/** Build */
async function emit(request: any) {
    setVerbosity(request.verbosity);
    debug(`# Beginning new work`);
    debug(`arguments: ${request.arguments.join(' ')}`)

    const inputs = Object.fromEntries(
        request.inputs.map((input: any) => [
            input.path,
            input.digest.byteLength ? Buffer.from(input.digest).toString("hex") : null
        ])
    );

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
            worker.invalidate(input as string, ts.FileWatcherEventKind.Created);
        }
        for (const input of changes) {
            worker.invalidate(input as string, ts.FileWatcherEventKind.Changed);
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
    const diagnostics = ts.getPreEmitDiagnostics(program as unknown as ts.Program, undefined, cancellationToken).concat(result?.diagnostics);
    timingEnd('diagnostics');

    const succeded = diagnostics.length === 0;

    if (!succeded) {
        request.output.write(worker.formatDiagnostics(diagnostics));
        isVerbose() && worker.printFSTree()
    }

    // @ts-expect-error
    if (ts.performance && ts.performance.isEnabled()) {
        // @ts-expect-error
        ts.performance.forEachMeasure((name: string, duration: number) => request.output.write(`${name} time: ${duration}\n`));
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
    // @ts-expect-error
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
    execute(ts.sys, noop, args);
}

export const __do_not_use_test_only__ = { createFilesystemTree: createFilesystemTree, emit: emit, workers: testOnlyGetWorkers() };