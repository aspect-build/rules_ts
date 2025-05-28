"UnitTests for ts_project and ts_config/tsconfig/extends"

load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//ts:defs.bzl", "ts_config", "ts_project")

def ts_config_test_suite(name):
    """Test suite including all tests and data

    Args:
        name: Target name of the test_suite target.
    """

    # A simple source file to compile
    write_file(
        name = "src_ts",
        out = "src_ts.ts",
        content = ["console.log(1)"],
        tags = ["manual"],
    )

    # A simple tsconfig file
    write_file(
        name = "src_tsconfig",
        out = "src_tsconfig.json",
        content = ["""{"compilerOptions": {"declaration": true, "outDir": "outdir"}}"""],
        tags = ["manual"],
    )
    write_file(
        name = "src_tsconfig2",
        out = "src_tsconfig2.json",
        content = ["""{"compilerOptions": {"declaration": true, "outDir": "outdir2"}}"""],
        tags = ["manual"],
    )

    # An extending tsconfig file
    write_file(
        name = "src_tsconfig_extending",
        out = "src_tsconfig_extending.json",
        content = ["""{"extends": "./src_tsconfig.json", "compilerOptions": {"outDir": "extending-outdir"}}"""],
        tags = ["manual"],
    )

    ts_config(
        name = "tsconfig",
        src = "src_tsconfig.json",
    )
    ts_config(
        name = "tsconfig_extending",
        src = "src_tsconfig_extending.json",
        deps = [":tsconfig"],
    )

    # Referencing a ts_config target
    ts_project(
        name = "use_tsconfig_target",
        srcs = [":src_ts"],
        declaration = True,
        out_dir = "outdir",
        tsconfig = ":tsconfig",
    )
    _ts_project_outputs_only_srcs_types_test(
        name = "outputs_tsconfig_target_test",
        target_under_test = "use_tsconfig_target",
    )

    # a dict() extending a tsconfig target
    ts_project(
        name = "use_tsconfig_dict",
        srcs = [":src_ts"],
        tsconfig = {"compilerOptions": {"declaration": True, "outDir": "dict-outdir"}},
        extends = ":tsconfig",
    )
    _ts_project_outputs_only_srcs_types_test(
        name = "outputs_tsconfig_dict_test",
        target_under_test = "use_tsconfig_dict",
    )

    # Referencing a config file
    ts_project(
        name = "use_tsconfig_file",
        srcs = [":src_ts"],
        declaration = True,
        out_dir = "outdir2",
        tsconfig = "src_tsconfig2.json",
    )
    _ts_project_outputs_only_srcs_types_test(
        name = "outputs_tsconfig_file_test",
        target_under_test = "use_tsconfig_file",
    )

    # a ts_config target with transitive deps
    ts_project(
        name = "use_extending_tsconfig_target",
        srcs = [":src_ts"],
        declaration = True,
        out_dir = "extending-outdir",
        tsconfig = ":tsconfig_extending",
    )
    _ts_project_outputs_only_srcs_types_test(
        name = "outputs_use_extending_tsconfig_target_test",
        target_under_test = "use_extending_tsconfig_target",
    )

    # a tsconfig dict() extending a ts_config()
    ts_project(
        name = "use_dict_extending_tsconfig_target",
        srcs = [":src_ts"],
        tsconfig = {"compilerOptions": {"declaration": True, "outDir": "dict-extending-outdir"}},
        extends = ":tsconfig_extending",
    )
    _ts_project_outputs_only_srcs_types_test(
        name = "outputs_use_dict_extending_tsconfig_target_test",
        target_under_test = "use_dict_extending_tsconfig_target",
    )

    native.test_suite(
        name = name,
        tests = [
            ":outputs_tsconfig_file_test",
            ":outputs_tsconfig_dict_test",
            ":outputs_tsconfig_target_test",
            ":outputs_use_extending_tsconfig_target_test",
            ":outputs_use_dict_extending_tsconfig_target_test",
        ],
    )

def _ts_project_outputs_only_srcs_types_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    jsinfo = target_under_test[JsInfo]

    output_types = sorted([f.path for f in jsinfo.types.to_list()])
    asserts.equals(env, 1, len(output_types))
    asserts.true(env, output_types[0].find("/src_ts.d.ts") != -1)

    output_transitive_types = sorted([f.path for f in jsinfo.transitive_types.to_list()])
    asserts.equals(env, 1, len(output_transitive_types))
    asserts.true(env, output_transitive_types[0].find("/src_ts.d.ts") != -1)

    output_sources = sorted([f.path for f in jsinfo.sources.to_list()])
    asserts.equals(env, 1, len(output_sources))
    asserts.true(env, output_sources[0].find("/src_ts.js") != -1)

    output_transitive_sources = sorted([f.path for f in jsinfo.transitive_sources.to_list()])
    asserts.equals(env, 1, len(output_transitive_sources))
    asserts.true(env, output_transitive_sources[0].find("/src_ts.js") != -1)

    return analysistest.end(env)

_ts_project_outputs_only_srcs_types_test = analysistest.make(_ts_project_outputs_only_srcs_types_test_impl)
