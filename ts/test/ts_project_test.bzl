"UnitTests for ts_project"

load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//ts:defs.bzl", "ts_project")

# dir_test
def _dir_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # assert the inputs to the tsc action are what we expect
    action_inputs = target_under_test[OutputGroupInfo]._action_inputs.to_list()
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

def _validate_tsconfig_exclude_test_impl(ctx):
    env = analysistest.begin(ctx)

    asserts.expect_failure(env, "tsconfig validation failed: when out_dir is set, exclude must also be set. See: https://github.com/aspect-build/rules_ts/issues/644 for more details.")

    return analysistest.end(env)

_validate_tsconfig_exclude_test = analysistest.make(_validate_tsconfig_exclude_test_impl, expect_failure = True)

# Use a dict() defined at the top level so it gets analyzed as part of .bzl file loading
# and is therefore immutable. See https://bazel.build/rules/language#mutability
_TSCONFIG = {
    "compilerOptions": {
        "declaration": True,
        "sourceMap": True,
    },
}

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

    ts_project(
        name = "validate_tsconfig_exclude",
        srcs = [],
        tsconfig = {
            "compilerOptions": {
                "outDir": ".",
            },
        },
        tags = ["manual"],
    )
    _validate_tsconfig_exclude_test(
        name = "validate_tsconfig_exclude_test",
        target_under_test = "validate_tsconfig_exclude",
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

    native.test_suite(
        name = name,
        tests = [
            ":dir_test",
            ":use_dir_test",
            ":wrapper_test",
            ":validate_tsconfig_exclude_test",
        ],
    )

def ts_project_wrapper(name, **kwargs):
    ts_project(
        name = name,
        **kwargs
    )
