const assert = require("node:assert");
const path = require("node:path");
const fs = require("node:fs");
const module_mock = require("./mock");
const test = require('node:test');

module_mock("typescript", {});
module_mock("./worker", {})

const worker = require("./ts_project_worker").__do_not_use_test_only__;
const root = path.join(process.env.GTEST_TMP_DIR, "workdir");

function touch(...paths) {
    for (let p of paths) {
        p = path.join(root, p);
        fs.mkdirSync(path.dirname(p), { recursive: true });
        fs.closeSync(fs.openSync(p, 'w'));
    }
}

function create_file(tree, ...paths) {
    touch(...paths)
    for (let p of paths) {
        tree.add(p)
    }
}

function create_dir_symlink(tree, from, to) {
    fs.mkdirSync(path.dirname(from), {recursive: true});
    fs.mkdirSync(path.dirname(to), {recursive: true});
    fs.symlinkSync(path.join(root, to), path.join(root, from), "dir");
    tree.add(from);
}

test.beforeEach(() => {
    fs.rmSync(root, {recursive: true, force: true});
    fs.mkdirSync(root);
    process.chdir(root);
});

test("directoryExists", () => {
    const tree = worker.createFilesystemTree(root, {});
    create_file(tree, "bazel-out/cfg/bin/input.js");
    assert.ok(tree.directoryExists("bazel-out"));
    assert.ok(tree.directoryExists("bazel-out/cfg"))
    assert.ok(tree.directoryExists("bazel-out/cfg/bin"))
});

test("readDirectory", () => {
    const tree = worker.createFilesystemTree(root, {});
    create_file(tree, "bazel-out/cfg/bin/input.js");
    create_file(tree, "bazel-out/cfg/bin/node_modules/.store/pkg/index.js")
    create_dir_symlink(tree, "bazel-out/cfg/bin/node_modules/pkg", "bazel-out/cfg/bin/node_modules/.store/pkg");

    assert.deepStrictEqual(tree.readDirectory("bazel-out"), ["bazel-out/cfg"]);
    assert.deepStrictEqual(tree.readDirectory("bazel-out/cfg"), ["bazel-out/cfg/bin"]);
    assert.deepStrictEqual(tree.readDirectory("bazel-out/cfg/bin"), ["bazel-out/cfg/bin/input.js", "bazel-out/cfg/bin/node_modules"]);
    assert.deepStrictEqual(tree.readDirectory("bazel-out/cfg/bin/node_modules/pkg"), ["bazel-out/cfg/bin/node_modules/pkg/index.js"]);
})

test("getDirectories", () => {
    const tree = worker.createFilesystemTree(root, {});
    create_file(tree, "bazel-out/cfg/bin/input.js");
    create_file(tree, "bazel-out/cfg/bin/node_modules/.store/pkg/index.js")
    create_dir_symlink(tree, "bazel-out/cfg/bin/node_modules/pkg", "bazel-out/cfg/bin/node_modules/.store/pkg");

    assert.deepStrictEqual(tree.getDirectories("bazel-out"), ["cfg"]);
    assert.deepStrictEqual(tree.getDirectories("bazel-out/cfg"), ["bin"]);
    assert.deepStrictEqual(tree.getDirectories("bazel-out/cfg/bin"), ["node_modules"]);
    assert.deepStrictEqual(tree.getDirectories("bazel-out/cfg/bin/node_modules"), [".store", "pkg"]);
})


test("normalizeIfSymlink", () => {
    const tree = worker.createFilesystemTree(root, {});
    create_file(tree, "bazel-out/cfg/bin/node_modules/.store/pkg/index.js")
    create_dir_symlink(tree, "bazel-out/cfg/bin/node_modules/pkg", "bazel-out/cfg/bin/node_modules/.store/pkg");
    assert.ok(tree.normalizeIfSymlink("bazel-out/cfg/bin/node_modules/pkg"));
})

test("realpath", () => {
    const tree = worker.createFilesystemTree(root, {});
    create_file(tree, "bazel-out/cfg/bin/node_modules/.store/pkg/index.js")
    create_dir_symlink(tree, "bazel-out/cfg/bin/node_modules/pkg", "bazel-out/cfg/bin/node_modules/.store/pkg");
    assert.equal(tree.realpath("bazel-out/cfg/bin/node_modules/pkg"), "/bazel-out/cfg/bin/node_modules/.store/pkg");
})

test("add", () => {
    const tree = worker.createFilesystemTree(root, {});
    create_file(tree, "tree/subtree/input.js", "tree/input.js");
    assert.deepStrictEqual(tree.getDirectories("tree"), ["subtree"]);
    assert.deepStrictEqual(tree.readDirectory("tree"), ["tree/subtree", "tree/input.js"]);
    assert.ok(tree.directoryExists("tree"));
    assert.ok(tree.directoryExists("tree/subtree"));
    assert.ok(!tree.directoryExists("tree/subtree/input.js"));
    assert.ok(tree.fileExists("tree/subtree/input.js"));
    assert.ok(!tree.fileExists("tree/subtree"));
    assert.ok(!tree.fileExists("tree"));
})

test("remove", () => {
    const tree = worker.createFilesystemTree(root, {});
    create_file(tree, "bazel-out/cfg/bin/input.js");
    create_file(tree, "bazel-out/cfg/bin/node_modules/.store/pkg/index.js")
    create_dir_symlink(tree, "bazel-out/cfg/bin/node_modules/pkg", "bazel-out/cfg/bin/node_modules/.store/pkg");

    assert.ok(tree.fileExists("bazel-out/cfg/bin/input.js"))
    tree.remove("bazel-out/cfg/bin/input.js")
    assert.ok(!tree.fileExists("bazel-out/cfg/bin/input.js"));
    assert.deepEqual(tree.readDirectory("bazel-out/cfg/bin"), ["bazel-out/cfg/bin/node_modules"])


    assert.ok(tree.directoryExists("bazel-out/cfg/bin/node_modules/pkg"))
    assert.ok(tree.normalizeIfSymlink("bazel-out/cfg/bin/node_modules/pkg"))
    tree.remove("bazel-out/cfg/bin/node_modules/pkg")
    assert.ok(!tree.normalizeIfSymlink("bazel-out/cfg/bin/node_modules/pkg"))
    assert.ok(!tree.directoryExists("bazel-out/cfg/bin/node_modules/pkg"))

    assert.ok(tree.directoryExists("bazel-out/cfg/bin/node_modules/.store/pkg"))
    tree.remove("bazel-out/cfg/bin/node_modules/.store/pkg")
    assert.ok(!tree.directoryExists("bazel-out/cfg/bin/node_modules/.store/pkg"))
    assert.ok(!tree.directoryExists("bazel-out/cfg/bin/node_modules"))
    assert.ok(!tree.directoryExists("bazel-out"))
})

test("symlink and directory mixed", () => {
    const tree = worker.createFilesystemTree(root, {});
    create_file(tree, "dir/input.js");
    create_dir_symlink(tree, "sym/s1", "dir");
    create_dir_symlink(tree, "sym/s2", "dir");
    create_file(tree, "sym/to/input.js");
    assert.deepStrictEqual(tree.getDirectories("sym"), ["s1", "s2", "to"])
})

test("dangling symlink", () => {
    const tree = worker.createFilesystemTree(root, {});
    fs.mkdirSync(path.join(root, "dangle"));
    fs.symlinkSync(path.join(root, "dangle"), path.join(root, "may_dangle"), "dir");
    tree.add("may_dangle")
    assert.equal(tree.directoryExists("may_dangle"), false)
    assert.equal(tree.directoryExists("may_dangle/underneath"), false)
    assert.equal(tree.fileExists("may_dangle"), false)
    assert.equal(tree.fileExists("may_dangle/file.js"), false)
    assert.deepEqual(tree.readDirectory("may_dangle"), [])
    assert.deepEqual(tree.getDirectories("may_dangle"), [])
    assert.deepEqual(tree.readDirectory("may_dangle/underneath"), [])
    assert.deepEqual(tree.getDirectories("may_dangle/underneath"), [])
});


function fn() {
    function mock(...args) {
        mock.calls.push({
            arguments: args
        });
    }
    mock.calls = [];
    return mock;
}

test("basic directory watcher", () => {
    const tree = worker.createFilesystemTree(root, {});
    const callback = fn();
    tree.watchDirectory("bazel-out/cfg/bin", callback);
    create_file(tree, "bazel-out/cfg/bin/1.js");
    assert.equal(callback.calls.length, 1);
    assert.deepEqual(callback.calls[0].arguments[0], "bazel-out/cfg/bin/1.js");
})


test("basic directory watcher", () => {
    const tree = worker.createFilesystemTree(root, {});
    const callback = fn();
    create_file(tree, "inputs/to/2.js");
    tree.watchDirectory("inputs/to", callback);
    create_file(tree, "inputs/to/1.js");
    assert.equal(callback.calls.length, 1);
    assert.deepEqual(callback.calls[0].arguments[0], "inputs/to/1.js");
})


test("basic file watcher", () => {
    const tree = worker.createFilesystemTree(root, {});
    const callback = fn();
    tree.watchFile("inputs/1.js", callback);
    create_file(tree, "inputs/1.js");
    assert.equal(callback.calls.length, 1);
    assert.deepEqual(callback.calls[0].arguments[0], "inputs/1.js");
})


test("directory watcher at files parent get notified", () => {
    const tree = worker.createFilesystemTree(root, {});
    const callback = fn();
    tree.watchDirectory("inputs", callback);
    create_file(tree, "inputs/1.js");
    assert.equal(callback.calls.length, 1);
    assert.deepEqual(callback.calls[0].arguments[0], "inputs/1.js");
});


test("file watcher gets notified on update", () => {
    const tree = worker.createFilesystemTree(root, {});
    const callback = fn();
    create_file(tree, "inputs/1.js");
    tree.watchFile("inputs/1.js", callback);
    tree.update("inputs/1.js")
    assert.equal(callback.calls.length, 1);
    assert.deepEqual(callback.calls[0].arguments[0], "inputs/1.js");
})


test("multiple file watchers get notified", () => {
    const tree = worker.createFilesystemTree(root, {});
    const callback1 = fn();
    const callback2 = fn();
    const callback3 = fn();
    const callback4 = fn();

    const close1 = tree.watchFile("inputs/1.js", callback1);
    tree.watchFile("inputs/1.js", callback2);
    const close3 = tree.watchFile("inputs/1.js", callback3);
    tree.watchFile("inputs/1.js", callback4);

    create_file(tree, "inputs/1.js");
    assert.deepStrictEqual(callback1.calls, [{arguments: ["inputs/1.js", 0]}]);
    assert.deepStrictEqual(callback2.calls, [{arguments: ["inputs/1.js", 0]}]);
    assert.deepStrictEqual(callback3.calls, [{arguments: ["inputs/1.js", 0]}]);
    assert.deepStrictEqual(callback4.calls, [{arguments: ["inputs/1.js", 0]}]);

    close1();
    close3();
    tree.remove("inputs/1.js")

    assert.deepStrictEqual(callback1.calls, [{arguments: ["inputs/1.js", 0]}]);
    assert.deepStrictEqual(callback2.calls, [{arguments: ["inputs/1.js", 0]}, {arguments: ["inputs/1.js", 2]}]);
    assert.deepStrictEqual(callback3.calls, [{arguments: ["inputs/1.js", 0]}]);
    assert.deepStrictEqual(callback4.calls, [{arguments: ["inputs/1.js", 0]}, {arguments: ["inputs/1.js", 2]}]);

})


test("recursive dir watchers get notified", () => {
    const tree = worker.createFilesystemTree(root, {});
    const callback = fn();
    tree.watchDirectory("recursive", callback, true);
    create_file(tree, "recursive/1.js");
    create_file(tree, "recursive/to/1.js");
    create_file(tree, "recursive/to/deep/1.js");
    assert.deepEqual(callback.calls.map(call => call.arguments[0]), [
        'recursive/1.js',
        'recursive/to',
        'recursive/to/1.js',
        'recursive/to/deep',
        'recursive/to/deep/1.js'
    ]);
})


test("no double calls for recursive dir watchers", () => {
    const tree = worker.createFilesystemTree(root, {});
    const callback = fn();
    tree.watchDirectory("recursive_behavior", callback, true);
    create_file(tree, "recursive_behavior/1.js");
    assert.deepStrictEqual(callback.calls, [{arguments: ["recursive_behavior/1.js", 0]}]);
})


test("mix of recursive and non-recursive should work", () => {
    const tree = worker.createFilesystemTree(root, {});
    const recursiveCallback = fn();
    const callback = fn();
    tree.watchDirectory("recursive", recursiveCallback, true);
    tree.watchDirectory("recursive", callback);
    create_file(tree, "recursive/1.js");
    assert.deepStrictEqual(callback.calls, [{arguments: ["recursive/1.js", 0]}]);
    assert.deepStrictEqual(recursiveCallback.calls, [{arguments: ["recursive/1.js", 0]}]);
});