const assert = require("node:assert");
const path = require("node:path");
const fs = require("node:fs");
const mod = require('node:module');

function mock(name, exports) {
    const p = path.resolve(name);
    require.cache[p] = {
        id: name,
        file: p,
        loaded: true,
        exports: exports
    };
    const realres = mod._resolveFilename;
    mod._resolveFilename = function (request, parent) {
        if (request == name) {
            return p;
        }
        return realres(request, parent);
    };
}

mock("typescript", { sys: { getCurrentDirectory: () => {}, realpath: fs.realpathSync } });
mock("@bazel/worker", { log: console.log })

/** @type {import("../private/ts_project_worker")} */
const worker = require("./ts_project_worker");




// Tests
const root = process.env.GTEST_TMP_DIR;

fs.mkdirSync(path.join(root, "symlink"));
fs.symlinkSync(path.join(root, "symlink"), path.join(root, "symlinked"), "dir");

fs.mkdirSync(path.join(root, 'not_a_symlink_but_null', 'deep'), {recursive: true});
fs.writeFileSync(path.join(root, 'not_a_symlink_but_null', 'deep', "input.js"), "")

const tree = worker.createFilesystemTree(root, {
    "tree/subtree/input.js": "1",
    "tree/input.js": "2",
    "symlink/to/me/input.js": "3",
    "symlinked": null,
    "not_a_symlink_but_null/deep/input.js": null,
});


assert.ok(tree.directoryExists("symlinked/to/me"));
assert.ok(!tree.fileExists("symlinked/to/me"));
assert.ok(!tree.fileExists("symlinked"));
assert.ok(tree.directoryExists("symlinked"));
assert.deepStrictEqual(tree.getDirectories("symlinked"), ["to"])
assert.deepStrictEqual(tree.readDirectory("symlinked"), ["to"])
assert.deepStrictEqual(tree.readDirectory("symlinked/to/me"), ["input.js"])

assert.deepStrictEqual(tree.readDirectory("not_a_symlink_but_null"), ["deep"])


assert.deepStrictEqual(tree.getDirectories("tree"), ["subtree"]);
assert.deepStrictEqual(tree.readDirectory("tree"), ["subtree", "input.js"]);


assert.ok(tree.directoryExists("tree"));
assert.ok(tree.directoryExists("tree/subtree"));
assert.ok(!tree.directoryExists("tree/subtree/input.js"));

assert.ok(tree.fileExists("tree/subtree/input.js"));
assert.ok(!tree.fileExists("tree/subtree"));
assert.ok(!tree.fileExists("tree"));


tree.remove("symlinked");
assert.ok(!tree.directoryExists("symlinked"));
assert.ok(!tree.directoryExists("symlinked/to"));


tree.add("symlinked/to/input.js", "1")
assert.ok(tree.directoryExists("symlinked"));
assert.ok(tree.directoryExists("symlinked/to"));
assert.ok(tree.fileExists("symlinked/to/input.js"));

tree.remove("symlinked/to/input.js");
assert.ok(!tree.directoryExists("symlinked"));
assert.ok(!tree.directoryExists("symlinked/to"));


tree.add("correct_remove/to/input.js", "1")
tree.add("correct_remove/to/path/input.js", "1")
tree.remove("correct_remove/to/path/input.js");
assert.ok(tree.fileExists("correct_remove/to/input.js"));
assert.ok(tree.directoryExists("correct_remove/to"));
assert.ok(!tree.directoryExists("correct_remove/to/path"));
assert.ok(!tree.fileExists("correct_remove/to/path/input.js"));

// Watcher
let calls = [];
let clean = tree.watchDirectory("inputs", (p) => calls.push(p));
tree.add("inputs/1.js", "1");
assert.deepEqual(calls, ["inputs", "inputs/1.js"]);
clean();

calls = [];
tree.add("inputs/to/2.js", "1");
clean = tree.watchDirectory("inputs/to", (p) => calls.push(p));
tree.add("inputs/to/1.js", "1");
assert.deepEqual(calls, ["inputs/to/1.js"]);
clean();
tree.remove("inputs");


calls = [];
clean = tree.watchFile("inputs/1.js", (p) => calls.push(p));
tree.add("inputs/1.js", "1");
assert.deepEqual(calls, ["inputs/1.js"]);
clean();


calls = [];
tree.add("inputs/1.js", "1");
let clean1 = tree.watchDirectory("inputs", (p) => calls.push(p));
let clean2 = tree.watchFile("inputs/1.js", (p) => calls.push(p));
tree.remove("inputs/1.js");
assert.deepEqual(calls, ["inputs/1.js", "inputs/1.js", "inputs"]);
clean1();
clean2();


calls = [];
tree.add("inputs/1.js", "1");
clean = tree.watchFile("inputs/1.js", (p) => calls.push(p));
tree.update("inputs/1.js", "2");
assert.deepEqual(calls, ["inputs/1.js"]);
clean();


calls = [];
let watcher1 = tree.watchFile("inputs/1.js", (p) => calls.push("watcher1"));
let watcher2 = tree.watchFile("inputs/1.js", (p) => calls.push("watcher2"));
let watcher3 = tree.watchFile("inputs/1.js", (p) => calls.push("watcher3"));
let watcher4 = tree.watchFile("inputs/1.js", (p) => calls.push("watcher4"));
watcher1();
watcher2();
tree.add("inputs/1.js", "2");
assert.deepEqual(calls, ["watcher3", "watcher4"]);
watcher3();
watcher4();
