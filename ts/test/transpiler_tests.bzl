"Unit tests for starlark API of ts_project with custom transpiler"

load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//ts:defs.bzl", "ts_project")
load(":mock_transpiler.bzl", "mock")

def _impl0(ctx):
    env = unittest.begin(ctx)

    decls = []
    for decl in ctx.attr.lib[JsInfo].types.to_list():
        decls.append(decl.basename)
    asserts.equals(env, ctx.attr.expected_types, sorted(decls))

    return unittest.end(env)

transitive_types_test = unittest.make(_impl0, attrs = {
    "lib": attr.label(default = ":transpile"),
    "expected_types": attr.string_list(default = ["big.d.ts"]),
})

def _impl1(ctx):
    env = unittest.begin(ctx)

    js_files = []
    for js in ctx.attr.lib[DefaultInfo].files.to_list():
        js_files.append(js.basename)
    asserts.equals(env, ctx.attr.expected_js, sorted(js_files))

    return unittest.end(env)

transpile_with_failing_typecheck_test = unittest.make(_impl1, attrs = {
    "lib": attr.label(default = ":transpile_with_typeerror"),
    "expected_js": attr.string_list(default = ["typeerror.js", "typeerror.js.map"]),
})

def _impl2(ctx):
    env = unittest.begin(ctx)

    js_files = []
    for js in ctx.attr.lib[DefaultInfo].files.to_list():
        js_files.append(js.basename)
    asserts.equals(env, ctx.attr.expected_js, sorted(js_files))

    return unittest.end(env)

transpile_with_dts_test = unittest.make(_impl2, attrs = {
    "lib": attr.label(default = ":transpile_with_dts"),
    "expected_js": attr.string_list(default = ["index.js", "index.js.map"]),
})

def _impl3(ctx):
    env = unittest.begin(ctx)

    js_files = []
    for js in ctx.attr.lib[DefaultInfo].files.to_list():
        js_files.append(js.basename)
    asserts.equals(env, ctx.attr.expected_js, sorted(js_files))

    decls = []
    for decl in ctx.attr.lib[JsInfo].types.to_list():
        decls.append(decl.basename)
    asserts.equals(env, ctx.attr.expected_types, sorted(decls))

    return unittest.end(env)

transitive_filegroup_test = unittest.make(_impl3, attrs = {
    "lib": attr.label(default = ":transpile_filegroup"),
    "expected_js": attr.string_list(default = ["src_fg_a.js", "src_fg_a.js.map", "src_fg_b.js", "src_fg_b.js.map"]),
    "expected_types": attr.string_list(default = ["src_fg_a.d.ts", "src_fg_b.d.ts"]),
})

# buildifier: disable=function-docstring
# buildifier: disable=unnamed-macro
def transpiler_test_suite():
    _TSCONFIG = {
        "compilerOptions": {
            "declaration": True,
            "sourceMap": True,
        },
    }

    write_file(
        name = "gen_ts",
        out = "big.ts",
        content = [
            "export const a{0}: number = {0}".format(x)
            for x in range(1000)
        ],
    )

    write_file(
        name = "gen_typeerror",
        out = "typeerror.ts",
        content = ["export const a: string = 1"],
    )

    write_file(
        name = "gen_lib_dts",
        out = "lib.d.ts",
        content = ["export const a: string;"],
    )

    write_file(
        name = "gen_index_ts",
        out = "index.ts",
        content = ["export const a: string = \"1\";"],
    )

    write_file(
        name = "gen_deep_src",
        out = "root/deep/root/deep_src.ts",
        content = ["export const a: string = \"1\";"],
    )

    ts_project(
        name = "transpile",
        srcs = ["big.ts"],
        transpiler = mock,
        tsconfig = _TSCONFIG,
    )

    # Ensure the output files are predeclared
    build_test(
        name = "out_refs_test",
        targets = [
            "big.js",
            "big.d.ts",
        ],
    )

    # This target proves that transpilation doesn't require typechecking:
    #
    # $ bazel build examples/swc:transpile_with_typeerror
    # INFO: Analyzed target //examples/swc:transpile_with_typeerror (1 packages loaded, 8 targets configured).
    # Target //examples/swc:transpile_with_typeerror up-to-date:
    #   bazel-bin/examples/swc/typeerror.js
    #
    # But the _typecheck target fails to build:
    #
    # $ bazel build examples/swc:transpile_with_typeerror_typecheck
    # INFO: Analyzed target //examples/swc:transpile_with_typeerror_typecheck (0 packages loaded, 1 target configured).
    # ERROR: /home/alexeagle/Projects/rules_ts/examples/swc/BUILD.bazel:30:11: Compiling TypeScript project //examples/swc:transpile_with_typeerror_typings
    # examples/swc/typeerror.ts(1,14): error TS2322: Type 'number' is not assignable to type 'string'
    ts_project(
        name = "transpile_with_typeerror",
        srcs = ["typeerror.ts"],
        # The transpile_with_typeerror.check target will have a build failure
        # But the default transpile_with_typeerror target should still produce JS outs
        tags = ["manual"],
        transpiler = mock,
        tsconfig = _TSCONFIG,
    )

    # Assert that the JS can be produced despite that type error
    build_test(
        name = "smoke_test",
        targets = ["typeerror.js"],
    )

    ts_project(
        name = "transpile_with_dts",
        srcs = [
            "index.ts",
            "lib.d.ts",
        ],
        tags = ["manual"],
        transpiler = mock,
        tsconfig = _TSCONFIG,
    )

    # ts_project srcs containing a filegroup()
    write_file(
        name = "src_filegroup_a",
        out = "src_fg_a.ts",
        content = ["export const a: string = \"1\";"],
    )

    write_file(
        name = "src_filegroup_b",
        out = "src_fg_b.ts",
        content = ["export const b: string = \"2\";"],
    )

    native.filegroup(
        name = "src_filegroup",
        srcs = [
            "src_fg_a.ts",
            "src_fg_b.ts",
        ],
    )

    ts_project(
        name = "transpile_filegroup",
        srcs = [":src_filegroup"],
        tags = ["manual"],
        transpiler = mock,
        tsconfig = _TSCONFIG,
    )

    unittest.suite("t0", transitive_types_test)
    unittest.suite("t1", transpile_with_failing_typecheck_test)
    unittest.suite("t2", transpile_with_dts_test)
    unittest.suite("t3", transitive_filegroup_test)
