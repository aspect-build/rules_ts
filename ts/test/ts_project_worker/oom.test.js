const assert = require("assert");
const mock = require("./mock");

const heapStatistics = { heap_size_limit: 100, used_heap_size: 0 }
mock("v8", { getHeapStatistics: () => heapStatistics })

let program_counter = 0;
const closed_programs = new Array();

class WatchProgram {
    constructor() {
        this.index = ++program_counter;
        heapStatistics.used_heap_size += 25;
        console.log()
    }
    getCurrentProgram() {
        return this;
    }
    emit() {
        return { emitSkipped: true }
    }
    close() {
        closed_programs.push(this.index)
        heapStatistics.used_heap_size -= 25;
    }
}
mock("typescript", {
    createWatchProgram: () => new WatchProgram(),
    createWatchCompilerHost: () => ({}),
    getPreEmitDiagnostics: () => ([]),
    parseCommandLine: () => ({ options: { project: "" } }),
    formatDiagnostics: () => "",
    sys: {
        getCurrentDirectory: process.cwd
    },
    performance: {
        isEnabled: () => false,
        mark: () => { },
        measure: () => { }
    }
});
mock("@bazel/worker", { log: console.log })

/** @type {import("../../private/ts_project_worker")} */
const worker = require("./ts_project_worker");

worker.emit(["--project", "p1", "--outDir", "p1", "--declarationDir", "p1", "--rootDir", "p1"], {})
worker.emit(["--project", "p2", "--outDir", "p2", "--declarationDir", "p2", "--rootDir", "p2"], {})
worker.emit(["--project", "p3", "--outDir", "p3", "--declarationDir", "p3", "--rootDir", "p3"], {})
worker.emit(["--project", "p4", "--outDir", "p4", "--declarationDir", "p4", "--rootDir", "p4"], {})
worker.emit(["--project", "p5", "--outDir", "p5", "--declarationDir", "p5", "--rootDir", "p5"], {})
assert.deepStrictEqual(closed_programs, [1]);

// now reuse p2 worker to prevent it from being the next victim by moving it to the end of the LRU cache. p3 should be the next victim.
worker.emit(["--project", "p2", "--outDir", "p2", "--declarationDir", "p2", "--rootDir", "p2"], {})
worker.emit(["--project", "p6", "--outDir", "p6", "--declarationDir", "p6", "--rootDir", "p6"], {})
assert.deepStrictEqual(closed_programs, [1,3]);

// reuse p4 so that p5 is the next victim.
worker.emit(["--project", "p4", "--outDir", "p4", "--declarationDir", "p4", "--rootDir", "p4"], {})
worker.emit(["--project", "p7", "--outDir", "p7", "--declarationDir", "p7", "--rootDir", "p7"], {})
assert.deepStrictEqual(closed_programs, [1,3,5]);

// reuse p2, p4, p7 to assert that they never get sweeped
worker.emit(["--project", "p2", "--outDir", "p2", "--declarationDir", "p2", "--rootDir", "p2"], {})
worker.emit(["--project", "p4", "--outDir", "p4", "--declarationDir", "p4", "--rootDir", "p4"], {})
worker.emit(["--project", "p7", "--outDir", "p7", "--declarationDir", "p7", "--rootDir", "p7"], {})
assert.deepStrictEqual(closed_programs, [1,3,5]);