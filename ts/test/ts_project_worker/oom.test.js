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
const ts_project_worker = require("./ts_project_worker").__do_not_use_test_only__

function killAllWorkers() {
    heapStatistics.used_heap_size = 0;
    program_counter = 0;
    closed_programs.length = 0;
    ts_project_worker.workers.clear();
}

ts_project_worker.emit(["--project", "p1", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p2", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p3", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p4", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p5", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
assert.deepStrictEqual(closed_programs, [1]);
killAllWorkers();

// Case: reuse p1 worker to prevent it from being the next victim by moving it to the end of the LRU cache. p2 should be the next victim.
ts_project_worker.emit(["--project", "p1", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p2", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p3", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})

ts_project_worker.emit(["--project", "p1", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})

ts_project_worker.emit(["--project", "p4", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p5", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
assert.deepStrictEqual(closed_programs, [2]);
killAllWorkers();

// Case: rescale p4
ts_project_worker.emit(["--project", "p1", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p2", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p3", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p4", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p4", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
assert.deepStrictEqual(closed_programs, [1]);

heapStatistics.used_heap_size = 81;
ts_project_worker.emit(["--project", "p4", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
assert.deepStrictEqual(closed_programs, [1,2]);
killAllWorkers();

// reuse p1, p3 to assert that they never get sweeped
ts_project_worker.emit(["--project", "p1", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p2", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})

ts_project_worker.emit(["--project", "p1", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})

ts_project_worker.emit(["--project", "p3", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
ts_project_worker.emit(["--project", "p4", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})

ts_project_worker.emit(["--project", "p3", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})

ts_project_worker.emit(["--project", "p5", "--outDir", ".", "--declarationDir", ".", "--rootDir", "."], {})
assert.deepStrictEqual(closed_programs, [2]);