"UnitTests for ts_project"

load("@aspect_rules_js//js:providers.bzl", "JsInfo", "js_info")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//ts:defs.bzl", "ts_config", "ts_project")

# dir_test
def _dir_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # assert the inputs to the tsc action are what we expect
    action_inputs = target_under_test[OutputGroupInfo]._action_inputs.to_list()
    action_inputs = sorted(action_inputs)
    asserts.equals(env, 2, len(action_inputs))
    asserts.true(env, action_inputs[0].path.find("/dir.ts") != -1)
    asserts.true(env, action_inputs[1].path.find("/tsconfig_dir.json") != -1)

    # sources should contain the .js output
    sources = target_under_test[JsInfo].sources.to_list()
    asserts.equals(env, 2, len(sources))
    asserts.true(env, sources[0].path.find("/dir.js") != -1)
    asserts.true(env, sources[1].path.find("/dir.js.map") != -1)

    # transitive_sources should contain the .js output
    transitive_sources = target_under_test[JsInfo].transitive_sources.to_list()
    asserts.equals(env, 2, len(transitive_sources))
    asserts.true(env, transitive_sources[0].path.find("/dir.js") != -1)
    asserts.true(env, transitive_sources[1].path.find("/dir.js.map") != -1)

    # types should only have the source types
    types = target_under_test[JsInfo].types.to_list()
    asserts.equals(env, 1, len(types))
    asserts.true(env, types[0].path.find("/dir.d.ts") != -1)

    # transitive_types should have the source types and transitive types
    transitive_types = target_under_test[JsInfo].transitive_types.to_list()
    asserts.equals(env, 1, len(transitive_types))
    asserts.true(env, transitive_types[0].path.find("/dir.d.ts") != -1)

    # types OutputGroupInfo should be the same as types
    asserts.equals(env, types, target_under_test[OutputGroupInfo].types.to_list())

    return analysistest.end(env)

_dir_test = analysistest.make(_dir_test_impl)

# use_dir_test
def _use_dir_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # assert the inputs to the tsc action are what we expect;
    # the inputs should *NOT* includes the sources from any deps or transitive deps;
    # only types from deps should be included as action inputs.
    action_inputs = target_under_test[OutputGroupInfo]._action_inputs.to_list()
    action_inputs = sorted([f.path for f in action_inputs])
    asserts.equals(env, 3, len(action_inputs))
    asserts.true(env, action_inputs[0].find("/dir.d.ts") != -1)
    asserts.true(env, action_inputs[1].find("/tsconfig_use_dir.json") != -1)
    asserts.true(env, action_inputs[2].find("/use_dir.ts") != -1)

    # sources should contain the .js output
    sources = target_under_test[JsInfo].sources.to_list()
    sources = sorted([f.path for f in sources])
    asserts.equals(env, 2, len(sources))
    asserts.true(env, sources[0].find("/use_dir.js") != -1)
    asserts.true(env, sources[1].find("/use_dir.js.map") != -1)

    # transitive_sources should contain the .js output
    transitive_sources = target_under_test[JsInfo].transitive_sources.to_list()
    transitive_sources = sorted([f.path for f in transitive_sources])
    asserts.equals(env, 4, len(transitive_sources))
    asserts.true(env, transitive_sources[0].find("/dir.js") != -1)
    asserts.true(env, transitive_sources[1].find("/dir.js.map") != -1)
    asserts.true(env, transitive_sources[2].find("/use_dir.js") != -1)
    asserts.true(env, transitive_sources[3].find("/use_dir.js.map") != -1)

    # types should only have the source types
    types = target_under_test[JsInfo].types.to_list()
    types = sorted([f.path for f in types])
    asserts.equals(env, 1, len(types))
    asserts.true(env, types[0].find("/use_dir.d.ts") != -1)

    # transitive_types should have the source types and transitive types
    transitive_types = target_under_test[JsInfo].transitive_types.to_list()
    transitive_types = sorted([f.path for f in transitive_types])
    asserts.equals(env, 2, len(transitive_types))
    asserts.true(env, transitive_types[0].find("/dir.d.ts") != -1)
    asserts.true(env, transitive_types[1].find("/use_dir.d.ts") != -1)

    # types OutputGroupInfo should be the same as types
    types_group = target_under_test[OutputGroupInfo].types.to_list()
    types_group = sorted([f.path for f in types_group])
    asserts.equals(env, types, types_group)

    return analysistest.end(env)

_use_dir_test = analysistest.make(_use_dir_test_impl)

def _declaration_map_dep_impl(ctx):
    type_file = ctx.actions.declare_file("provider_type.d.ts")
    type_map = ctx.actions.declare_file("provider_type.d.ts.map")
    npm_type = ctx.actions.declare_file("npm_type.d.mts")
    npm_map = ctx.actions.declare_file("npm_type.d.mts.map")
    npm_commonjs_type = ctx.actions.declare_file("npm_type.d.cts")
    npm_commonjs_map = ctx.actions.declare_file("npm_type.d.cts.map")
    js_map = ctx.actions.declare_file("npm_source.js.map")
    for file in [type_file, npm_type, npm_commonjs_type]:
        ctx.actions.write(file, "export declare const value: string;\n")
    for file in [type_map, npm_map, npm_commonjs_map, js_map]:
        ctx.actions.write(file, '{"version":3,"sources":[],"mappings":""}\n')

    types = depset([type_file, type_map])
    npm_sources = depset([npm_type, npm_map, npm_commonjs_type, npm_commonjs_map, js_map])
    return [
        DefaultInfo(files = depset(transitive = [types, npm_sources])),
        js_info(
            target = ctx.label,
            types = types,
            transitive_types = types,
            npm_sources = npm_sources,
        ),
    ]

_declaration_map_dep = rule(implementation = _declaration_map_dep_impl)

def _declaration_map_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    inputs = [file.basename for file in target[OutputGroupInfo]._action_inputs.to_list()]

    for name in ["provider_type.d.ts", "npm_type.d.mts", "npm_type.d.cts", "npm_source.js.map"]:
        asserts.true(env, name in inputs, "expected {} in compiler inputs".format(name))
    for name in ["provider_type.d.ts.map", "npm_type.d.mts.map", "npm_type.d.cts.map"]:
        asserts.false(env, name in inputs, "unexpected {} in compiler inputs".format(name))

    # Maps remain in JsInfo for downstream consumers, even though tsc does not read them.
    types = [file.basename for file in target[JsInfo].transitive_types.to_list()]
    npm_sources = [file.basename for file in target[JsInfo].npm_sources.to_list()]
    asserts.true(env, "provider_type.d.ts.map" in types)
    asserts.true(env, "npm_type.d.mts.map" in npm_sources)
    asserts.true(env, "npm_type.d.cts.map" in npm_sources)
    return analysistest.end(env)

_declaration_map_inputs_test = analysistest.make(_declaration_map_inputs_test_impl)

def _emitted_declaration_map_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    inputs = [file.basename for file in target[OutputGroupInfo]._action_inputs.to_list()]
    types = [file.basename for file in target[JsInfo].transitive_types.to_list()]
    asserts.true(env, "declaration_map_emitter.d.ts" in inputs)
    asserts.false(env, "declaration_map_emitter.d.ts.map" in inputs)
    asserts.true(env, "declaration_map_emitter.d.ts.map" in types)
    return analysistest.end(env)

_emitted_declaration_map_inputs_test = analysistest.make(_emitted_declaration_map_inputs_test_impl)

def _declaration_map_tsconfig_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    compiler_inputs = [file.basename for file in target[OutputGroupInfo]._action_inputs.to_list()]
    validation_actions = [action for action in analysistest.target_actions(env) if action.mnemonic == "TsValidateOptions"]
    asserts.equals(env, 1, len(validation_actions))

    for inputs in [compiler_inputs] + [[file.basename for file in action.inputs.to_list()] for action in validation_actions]:
        for name in ["provider_type.d.ts", "npm_type.d.mts", "npm_type.d.cts", "npm_source.js.map"]:
            asserts.true(env, name in inputs, "expected {} in action inputs".format(name))
        for name in ["provider_type.d.ts.map", "npm_type.d.mts.map", "npm_type.d.cts.map"]:
            asserts.false(env, name in inputs, "unexpected {} in action inputs".format(name))

    return analysistest.end(env)

_declaration_map_tsconfig_inputs_test = analysistest.make(_declaration_map_tsconfig_inputs_test_impl)

# Use a dict() defined at the top level so it gets analyzed as part of .bzl file loading
# and is therefore immutable. See https://bazel.build/rules/language#mutability
_TSCONFIG = {
    "compilerOptions": {
        "declaration": True,
        "sourceMap": True,
    },
}

_TSCONFIG_JS_ONLY = {
    "compilerOptions": {
        "declaration": False,
    },
}

# no_decl_lib_transitive_typecheck_test
# Verifies that when declaration=False, js_outs appear in transitive_typecheck (the fix).
def _no_decl_lib_transitive_typecheck_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    files = target[OutputGroupInfo].transitive_typecheck.to_list()
    asserts.equals(env, 1, len(files))
    asserts.true(env, files[0].path.find(".js") != -1)

    return analysistest.end(env)

_no_decl_lib_transitive_typecheck_test = analysistest.make(_no_decl_lib_transitive_typecheck_test_impl)

# no_decl_consumer_transitive_typecheck_test
# Verifies that transitive_typecheck chains correctly through declaration=False deps.
def _no_decl_consumer_transitive_typecheck_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    files = target[OutputGroupInfo].transitive_typecheck.to_list()
    asserts.equals(env, 2, len(files))

    return analysistest.end(env)

_no_decl_consumer_transitive_typecheck_test = analysistest.make(_no_decl_consumer_transitive_typecheck_test_impl)

def ts_project_test_suite(name):
    """Test suite including all tests and data

    Args:
        name: Target name of the test_suite target.
    """

    write_file(
        name = "dir_ts",
        out = "dir.ts",
        content = ["import { dirname } from 'path'; export const dir = dirname(__filename);"],
        tags = ["manual"],
    )
    ts_project(
        name = "dir",
        srcs = ["dir.ts"],
        tsconfig = _TSCONFIG,
        tags = ["manual"],
    )
    _dir_test(
        name = "dir_test",
        target_under_test = "dir",
    )

    # Pin the content of the resolved tsconfig emitted by the validation action.
    # This is the contract a replacement resolver (e.g. a native `tsc --showConfig`
    # action for typescript >= 7) must reproduce.
    # NB: the golden deliberately has no .json extension: formatters would reformat
    # it away from the byte-exact validator output.
    native.filegroup(
        name = "dir_validation_output",
        srcs = [":dir"],
        output_group = "_validation",
        tags = ["manual"],
    )
    diff_test(
        name = "dir_resolved_tsconfig_test",
        file1 = "dir.resolved.tsconfig.golden",
        file2 = ":dir_validation_output",
    )

    # When "exclude" is unspecified, tsc materializes the implicit exclusion of outDir
    # as an ABSOLUTE path, which the validator must relativize for hermetic output.
    # The golden pins that relativization, including on windows where tsc prints
    # forward-slash absolute paths.
    write_file(
        name = "implicit_exclude_ts",
        out = "implicit_exclude.ts",
        content = ["export const a = 1"],
        tags = ["manual"],
    )
    write_file(
        name = "tsconfig_implicit_exclude",
        out = "tsconfig_implicit_exclude.json",
        content = ['{"compilerOptions": {"declaration": true, "outDir": "implicit_exclude_out"}, "files": ["implicit_exclude.ts"]}'],
        tags = ["manual"],
    )
    ts_project(
        name = "implicit_exclude",
        srcs = [":implicit_exclude_ts"],
        declaration = True,
        out_dir = "implicit_exclude_out",
        tsconfig = ":tsconfig_implicit_exclude",
        tags = ["manual"],
    )
    native.filegroup(
        name = "implicit_exclude_validation_output",
        srcs = [":implicit_exclude"],
        output_group = "_validation",
        tags = ["manual"],
    )
    diff_test(
        name = "implicit_exclude_resolved_tsconfig_test",
        file1 = "implicit_exclude.resolved.tsconfig.golden",
        file2 = ":implicit_exclude_validation_output",
    )

    write_file(
        name = "use_dir_ts",
        out = "use_dir.ts",
        content = ["import { dir } from './dir'; export const another_dir = dir;"],
        tags = ["manual"],
    )
    ts_project(
        name = "use_dir",
        srcs = ["use_dir.ts"],
        deps = ["dir"],
        tsconfig = _TSCONFIG,
        tags = ["manual"],
    )
    _use_dir_test(
        name = "use_dir_test",
        target_under_test = "use_dir",
    )

    _declaration_map_dep(name = "declaration_map_dep")
    write_file(
        name = "declaration_map_consumer_ts",
        out = "declaration_map_consumer.ts",
        content = ["export const value = 1;"],
        tags = ["manual"],
    )
    ts_project(
        name = "declaration_map_consumer",
        srcs = ["declaration_map_consumer.ts"],
        deps = [":declaration_map_dep"],
        tsconfig = {"compilerOptions": {"noEmit": True}},
        tags = ["manual"],
    )
    _declaration_map_inputs_test(
        name = "declaration_map_inputs_test",
        target_under_test = "declaration_map_consumer",
    )
    ts_project(
        name = "declaration_map_transitive_consumer",
        srcs = ["declaration_map_consumer.ts"],
        deps = [":declaration_map_consumer"],
        tsconfig = {"compilerOptions": {"noEmit": True}},
        tags = ["manual"],
    )
    _declaration_map_inputs_test(
        name = "declaration_map_transitive_inputs_test",
        target_under_test = "declaration_map_transitive_consumer",
    )
    write_file(
        name = "declaration_map_emitter_ts",
        out = "declaration_map_emitter.ts",
        content = ["export const value = 1;"],
        tags = ["manual"],
    )
    ts_project(
        name = "declaration_map_emitter",
        srcs = ["declaration_map_emitter.ts"],
        declaration = True,
        declaration_map = True,
        tsconfig = {"compilerOptions": {"declaration": True, "declarationMap": True}},
        tags = ["manual"],
    )
    ts_project(
        name = "declaration_map_emitted_consumer",
        srcs = ["declaration_map_consumer.ts"],
        deps = [":declaration_map_emitter"],
        tsconfig = {"compilerOptions": {"noEmit": True}},
        tags = ["manual"],
    )
    _emitted_declaration_map_inputs_test(
        name = "emitted_declaration_map_inputs_test",
        target_under_test = "declaration_map_emitted_consumer",
    )

    write_file(
        name = "declaration_map_tsconfig_json",
        out = "declaration_map_tsconfig.json",
        content = ['{"files":["declaration_map_consumer.ts"],"compilerOptions":{"noEmit":true}}'],
        tags = ["manual"],
    )
    ts_config(
        name = "declaration_map_tsconfig",
        src = ":declaration_map_tsconfig_json",
        deps = [":declaration_map_dep"],
    )
    ts_config(
        name = "declaration_map_nested_tsconfig",
        src = ":declaration_map_tsconfig",
    )
    ts_project(
        name = "declaration_map_tsconfig_consumer",
        srcs = ["declaration_map_consumer.ts"],
        no_emit = True,
        tsconfig = ":declaration_map_nested_tsconfig",
        tags = ["manual"],
    )
    _declaration_map_tsconfig_inputs_test(
        name = "declaration_map_tsconfig_inputs_test",
        target_under_test = "declaration_map_tsconfig_consumer",
    )

    write_file(
        name = "declaration_map_composite_ts",
        out = "declaration_map_composite.ts",
        content = ["export const value = 1;"],
        tags = ["manual"],
    )
    ts_project(
        name = "declaration_map_composite_consumer",
        srcs = ["declaration_map_composite.ts"],
        deps = [":declaration_map_tsconfig"],
        composite = True,
        tsconfig = {"compilerOptions": {"composite": True, "declaration": True}},
        tags = ["manual"],
    )
    _declaration_map_tsconfig_inputs_test(
        name = "declaration_map_composite_inputs_test",
        target_under_test = "declaration_map_composite_consumer",
    )

    write_file(
        name = "wrapper_ts",
        out = "wrapper.ts",
        content = ["console.log(1)"],
        tags = ["manual"],
    )
    ts_project_wrapper(
        name = "wrapper",
        srcs = ["wrapper.ts"],
        declaration_map = True,  # a value that will override the tsconfig dict()
        tsconfig = _TSCONFIG,
        tags = ["manual"],
    )

    build_test(
        name = "wrapper_test",
        targets = [":wrapper.d.ts.map"],
    )

    write_file(
        name = "dirty_out_dir_ts",
        out = "dirty_out_dir.ts",
        content = ["console.log(1)"],
        tags = ["manual"],
    )
    ts_project_wrapper(
        name = "dirty_out_dir",
        srcs = ["dirty_out_dir.ts"],
        out_dir = "./out-dir",
        tsconfig = _TSCONFIG,
        tags = ["manual"],
    )

    build_test(
        name = "dirty_out_dir_test",
        targets = [":dirty_out_dir"],
    )

    # Path-normalization tests: verify that ./path, path/, and ./path/ are all
    # accepted as equivalent for outDir, declarationDir, and rootDir together.
    # Each variant uses a distinct directory tree so outputs never conflict.

    # Leading ./: tsconfig uses ./out1, ./types1, ./nrm1
    write_file(
        name = "path_norm1_ts",
        out = "nrm1/src1.ts",
        content = ["export const x = 1"],
        tags = ["manual"],
    )
    ts_project_wrapper(
        name = "path_norm_dotslash",
        srcs = [":path_norm1_ts"],
        declaration = True,
        tsconfig = {
            "compilerOptions": {
                "outDir": "./out1",
                "declaration": True,
                "declarationDir": "./types1",
                "rootDir": "./nrm1",
            },
            "exclude": [],
        },
        tags = ["manual"],
    )
    build_test(
        name = "path_norm_dotslash_test",
        targets = [":path_norm_dotslash"],
    )

    # Trailing /: tsconfig uses out2/, types2/, nrm2/
    write_file(
        name = "path_norm2_ts",
        out = "nrm2/src2.ts",
        content = ["export const x = 1"],
        tags = ["manual"],
    )
    write_file(
        name = "tsconfig_path_norm_trailing_slash",
        out = "tsconfig_path_norm_trailing_slash.json",
        content = ['{"files": ["nrm2/src2.ts"], "compilerOptions": {"outDir": "out2/", "declaration": true, "declarationDir": "types2/", "rootDir": "nrm2/"}, "exclude": []}'],
        tags = ["manual"],
    )
    ts_project_wrapper(
        name = "path_norm_trailing_slash",
        srcs = [":path_norm2_ts"],
        declaration = True,
        out_dir = "out2",
        declaration_dir = "types2",
        root_dir = "nrm2",
        tsconfig = ":tsconfig_path_norm_trailing_slash",
        tags = ["manual"],
    )
    build_test(
        name = "path_norm_trailing_slash_test",
        targets = [":path_norm_trailing_slash"],
    )

    # Both ./ and /: tsconfig uses ./out3/, ./types3/, ./nrm3/
    write_file(
        name = "path_norm3_ts",
        out = "nrm3/src3.ts",
        content = ["export const x = 1"],
        tags = ["manual"],
    )
    write_file(
        name = "tsconfig_path_norm_both_slash",
        out = "tsconfig_path_norm_both_slash.json",
        content = ['{"files": ["nrm3/src3.ts"], "compilerOptions": {"outDir": "./out3/", "declaration": true, "declarationDir": "./types3/", "rootDir": "./nrm3/"}, "exclude": []}'],
        tags = ["manual"],
    )
    ts_project_wrapper(
        name = "path_norm_both_slash",
        srcs = [":path_norm3_ts"],
        declaration = True,
        out_dir = "out3",
        declaration_dir = "types3",
        root_dir = "nrm3",
        tsconfig = ":tsconfig_path_norm_both_slash",
        tags = ["manual"],
    )
    build_test(
        name = "path_norm_both_slash_test",
        targets = [":path_norm_both_slash"],
    )

    write_file(
        name = "no_decl_lib_ts",
        out = "no_decl_lib.ts",
        content = ["export const x = 1;"],
        tags = ["manual"],
    )
    ts_project(
        name = "no_decl_lib",
        srcs = ["no_decl_lib.ts"],
        tsconfig = _TSCONFIG_JS_ONLY,
        tags = ["manual"],
    )
    _no_decl_lib_transitive_typecheck_test(
        name = "no_decl_lib_transitive_typecheck_analysis_test",
        target_under_test = "no_decl_lib",
    )

    write_file(
        name = "no_decl_consumer_ts",
        out = "no_decl_consumer.ts",
        content = ["export const y = 2;"],
        tags = ["manual"],
    )
    ts_project(
        name = "no_decl_consumer",
        srcs = ["no_decl_consumer.ts"],
        deps = [":no_decl_lib"],
        tsconfig = _TSCONFIG_JS_ONLY,
        tags = ["manual"],
    )
    _no_decl_consumer_transitive_typecheck_test(
        name = "no_decl_consumer_transitive_typecheck_analysis_test",
        target_under_test = "no_decl_consumer",
    )

    native.test_suite(
        name = name,
        tests = [
            ":dir_test",
            ":use_dir_test",
            ":declaration_map_inputs_test",
            ":declaration_map_transitive_inputs_test",
            ":emitted_declaration_map_inputs_test",
            ":declaration_map_tsconfig_inputs_test",
            ":declaration_map_composite_inputs_test",
            ":wrapper_test",
            ":dirty_out_dir_test",
            ":path_norm_dotslash_test",
            ":path_norm_trailing_slash_test",
            ":path_norm_both_slash_test",
            ":no_decl_lib_transitive_typecheck_analysis_test",
            ":no_decl_consumer_transitive_typecheck_analysis_test",
        ],
    )

def ts_project_wrapper(name, **kwargs):
    ts_project(
        name = name,
        **kwargs
    )
