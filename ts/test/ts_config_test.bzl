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

    # A simple tsconfig file.
    # NB: fixture tsconfigs pin `files` so tsc only compiles the intended
    # sources. Without it tsc includes every .ts it can see, which is
    # non-hermetic on hosts without sandboxing (e.g. Windows) where files
    # generated for sibling targets (such as typeerror.ts) are also visible.
    write_file(
        name = "src_tsconfig",
        out = "src_tsconfig.json",
        content = ["""{"files": ["src_ts.ts"], "compilerOptions": {"declaration": true, "outDir": "outdir"}}"""],
        tags = ["manual"],
    )
    write_file(
        name = "src_tsconfig2",
        out = "src_tsconfig2.json",
        content = ["""{"files": ["src_ts.ts"], "compilerOptions": {"declaration": true, "outDir": "outdir2"}}"""],
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

    # A package.json that ts_config should accept as a non-tsconfig dep so
    # TypeScript can read its "type"/"exports" fields during module
    # resolution (e.g. nodenext + verbatimModuleSyntax requires a sibling
    # `"type": "module"` to classify a .ts file as ESM).
    write_file(
        name = "src_package_json",
        out = "package.json",
        content = ["""{"name": "pkg", "version": "0.0.0", "type": "module"}"""],
        tags = ["manual"],
    )

    # ts_config receiving a package.json via deps. Uses a dedicated tsconfig
    # so the consuming ts_project below can declare a unique `out_dir` that
    # matches the tsconfig's `outDir` (rules_ts validates these agree).
    write_file(
        name = "src_tsconfig_pkgjson",
        out = "src_tsconfig_pkgjson.json",
        content = ["""{"files": ["src_ts.ts"], "compilerOptions": {"declaration": true, "outDir": "pkgjson-outdir"}}"""],
        tags = ["manual"],
    )
    ts_config(
        name = "tsconfig_with_package_json_dep",
        src = "src_tsconfig_pkgjson.json",
        deps = [":src_package_json"],
    )
    ts_project(
        name = "use_tsconfig_with_package_json_dep",
        srcs = [":src_ts"],
        declaration = True,
        out_dir = "pkgjson-outdir",
        tsconfig = ":tsconfig_with_package_json_dep",
    )

    # ts_config whose src is another ts_config target (mirrors the
    # examples/package_json_usage/parent_src pattern, where a child
    # ts_config consumes a parent ts_config's bin-tree-copied tsconfig.json
    # via `src`). The package.json dep should still flow through to tsc.
    write_file(
        name = "src_tsconfig_wrapparent",
        out = "src_tsconfig_wrapparent.json",
        content = ["""{"files": ["src_ts.ts"], "compilerOptions": {"declaration": true, "outDir": "wrap-outdir"}}"""],
        tags = ["manual"],
    )
    ts_config(
        name = "tsconfig_wrap_parent",
        src = "src_tsconfig_wrapparent.json",
    )
    ts_config(
        name = "tsconfig_wrapping_ts_config",
        src = ":tsconfig_wrap_parent",
        deps = [":src_package_json"],
    )
    ts_project(
        name = "use_tsconfig_wrapping_ts_config",
        srcs = [":src_ts"],
        declaration = True,
        out_dir = "wrap-outdir",
        tsconfig = ":tsconfig_wrapping_ts_config",
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

    _ts_project_sees_package_json_in_tsc_inputs_test(
        name = "tsconfig_with_package_json_dep_test",
        target_under_test = "use_tsconfig_with_package_json_dep",
    )

    _ts_project_sees_package_json_in_tsc_inputs_test(
        name = "tsconfig_wrapping_ts_config_test",
        target_under_test = "use_tsconfig_wrapping_ts_config",
    )

    native.test_suite(
        name = name,
        tests = [
            ":outputs_tsconfig_file_test",
            ":outputs_tsconfig_dict_test",
            ":outputs_tsconfig_target_test",
            ":outputs_use_extending_tsconfig_target_test",
            ":outputs_use_dict_extending_tsconfig_target_test",
            ":tsconfig_with_package_json_dep_test",
            ":tsconfig_wrapping_ts_config_test",
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

def _ts_project_sees_package_json_in_tsc_inputs_test_impl(ctx):
    """Asserts that a package.json attached to ts_config(deps=...) reaches tsc.

    For TypeScript to actually use the package.json (e.g. read "type" for
    ESM/CJS classification under nodenext + verbatimModuleSyntax, or "exports"
    for module resolution), the file must:
      1. Be part of the tsc action's input set, and
      2. Live at a path TypeScript walks — namely, alongside (or above) the
         .ts source files, since module resolution looks for the *nearest*
         package.json starting from each source file.
    """
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    action_input_paths = sorted([f.path for f in target_under_test[OutputGroupInfo]._action_inputs.to_list()])

    src_inputs = [p for p in action_input_paths if p.endswith(".ts")]
    asserts.equals(env, 1, len(src_inputs))
    src_dir = src_inputs[0].rsplit("/", 1)[0]

    expected_package_json = src_dir + "/package.json"
    asserts.true(
        env,
        expected_package_json in action_input_paths,
        "expected {} among tsc action inputs (so TypeScript's nearest-package-json walk finds it next to the source), got: {}".format(
            expected_package_json,
            action_input_paths,
        ),
    )

    return analysistest.end(env)

_ts_project_sees_package_json_in_tsc_inputs_test = analysistest.make(_ts_project_sees_package_json_in_tsc_inputs_test_impl)
