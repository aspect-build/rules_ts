"UnitTests for ts_project"

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("//ts:defs.bzl", "ts_project")

# dir_test
def _dir_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # assert the inputs to the tsc action are what we expect
    action_inputs = target_under_test[OutputGroupInfo]._action_inputs.to_list()
    asserts.equals(env, 3, len(action_inputs))
    asserts.true(env, action_inputs[0].path.find("/dir.ts") != -1)
    asserts.true(env, action_inputs[1].path.find("/_validate_dir_options.optionsvalid.d.ts") != -1)
    asserts.true(env, action_inputs[2].path.find("/tsconfig_dir.json") != -1)

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

    # declarations should only have the source declarations
    declarations = target_under_test[JsInfo].declarations.to_list()
    asserts.equals(env, 1, len(declarations))
    asserts.true(env, declarations[0].path.find("/dir.d.ts") != -1)

    # transitive_declarations should have the source declarations and transitive declarations
    transitive_declarations = target_under_test[JsInfo].transitive_declarations.to_list()
    asserts.equals(env, 1, len(transitive_declarations))
    asserts.true(env, transitive_declarations[0].path.find("/dir.d.ts") != -1)

    # types OutputGroupInfo should be the same as declarations
    asserts.equals(env, declarations, target_under_test[OutputGroupInfo].types.to_list())

    return analysistest.end(env)

_dir_test = analysistest.make(_dir_test_impl)

# use_dir_test
def _use_dir_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # assert the inputs to the tsc action are what we expect;
    # the inputs should *NOT* includes the sources from any deps or transitive deps;
    # only declarations from deps should be included as action inputs.
    action_inputs = target_under_test[OutputGroupInfo]._action_inputs.to_list()
    asserts.equals(env, 4, len(action_inputs))
    asserts.true(env, action_inputs[0].path.find("/dir.d.ts") != -1)
    asserts.true(env, action_inputs[1].path.find("/use_dir.ts") != -1)
    asserts.true(env, action_inputs[2].path.find("/_validate_use_dir_options.optionsvalid.d.ts") != -1)
    asserts.true(env, action_inputs[3].path.find("/tsconfig_use_dir.json") != -1)

    # sources should contain the .js output
    sources = target_under_test[JsInfo].sources.to_list()
    asserts.equals(env, 2, len(sources))
    asserts.true(env, sources[0].path.find("/use_dir.js") != -1)
    asserts.true(env, sources[1].path.find("/use_dir.js.map") != -1)

    # transitive_sources should contain the .js output
    transitive_sources = target_under_test[JsInfo].transitive_sources.to_list()
    asserts.equals(env, 4, len(transitive_sources))
    asserts.true(env, transitive_sources[0].path.find("/use_dir.js") != -1)
    asserts.true(env, transitive_sources[1].path.find("/use_dir.js.map") != -1)
    asserts.true(env, transitive_sources[2].path.find("/dir.js") != -1)
    asserts.true(env, transitive_sources[3].path.find("/dir.js.map") != -1)

    # declarations should only have the source declarations
    declarations = target_under_test[JsInfo].declarations.to_list()
    asserts.equals(env, 1, len(declarations))
    asserts.true(env, declarations[0].path.find("/use_dir.d.ts") != -1)

    # transitive_declarations should have the source declarations and transitive declarations
    transitive_declarations = target_under_test[JsInfo].transitive_declarations.to_list()
    asserts.equals(env, 2, len(transitive_declarations))
    asserts.true(env, transitive_declarations[0].path.find("/use_dir.d.ts") != -1)
    asserts.true(env, transitive_declarations[1].path.find("/dir.d.ts") != -1)

    # types OutputGroupInfo should be the same as declarations
    asserts.equals(env, declarations, target_under_test[OutputGroupInfo].types.to_list())

    return analysistest.end(env)

_use_dir_test = analysistest.make(_use_dir_test_impl)


# supports_workers test explicitly true
def _supports_workers_explicitly_true_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = target_under_test.actions[0]
    asserts.true(env, action.argv[0].find("npm_typescript/tsc_worker.sh") != -1, "expected workers to be enabled explicitly.")
    return analysistest.end(env)

_supports_workers_explicitly_true_test = analysistest.make(
    _supports_workers_explicitly_true_test_impl,
    config_settings = { "@aspect_rules_ts//ts:supports_workers": "false" }
)

# supports_workers test explicitly false
def _supports_workers_explicitly_false_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    found_action = None
    for action in target_under_test.actions:
        if action.mnemonic == "TsProject":
            found_action = action
            break
    asserts.true(env, found_action != None, "cant find the action")
    asserts.true(env, found_action.argv[0].find("npm_typescript/tsc.sh") != -1, "expected workers to be disabled explicitly.")
    return analysistest.end(env)

_supports_workers_explicitly_false_test = analysistest.make(
    _supports_workers_explicitly_false_test_impl,
    config_settings = { "@aspect_rules_ts//ts:supports_workers": "true" }
)


# supports_workers test implicitly true
def _supports_workers_implicitly_true_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    found_action = None
    for action in target_under_test.actions:
        if action.mnemonic == "TsProject":
            found_action = action
            break
    asserts.true(env, found_action != None, "cant find the action")
    asserts.true(env, found_action.argv[0].find("npm_typescript/tsc_worker.sh") != -1, "expected workers to be enabled globally.")
    return analysistest.end(env)

_supports_workers_implicitly_true_test = analysistest.make(
    _supports_workers_implicitly_true_test_impl,
    config_settings = { "@aspect_rules_ts//ts:supports_workers": "false" }
)

# supports_workers test implicitly false
def _supports_workers_implicitly_false_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    found_action = None
    for action in target_under_test.actions:
        if action.mnemonic == "TsProject":
            found_action = action
            break
    asserts.true(env, found_action != None, "cant find the action")
    #asserts.true(env, found_action.argv[0].find("npm_typescript/tsc.sh") != -1, "expected workers to be disabled globally.")
    return analysistest.end(env)

_supports_workers_implicitly_false_test = analysistest.make(
    _supports_workers_implicitly_false_test_impl,
    config_settings = { "@aspect_rules_ts//ts:supports_workers": "false" }
)


# verbose test  true
def _verbose_true_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = target_under_test.actions[0]
    asserts.true(env, action.argv.index("--listFiles") != -1)
    asserts.true(env, action.argv.index("--listEmittedFiles") != -1)
    asserts.true(env, action.argv.index("--traceResolution") != -1)
    asserts.true(env, action.argv.index("--diagnostics") != -1)
    asserts.true(env, action.argv.index("--extendedDiagnostics") != -1)
    return analysistest.end(env)

_verbose_true_test = analysistest.make(
    _verbose_true_test_impl,
    config_settings = { "@aspect_rules_ts//ts:verbose": "true" }
)

# verbose test  false
def _verbose_false_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = target_under_test.actions[0]
    asserts.true(env, action.argv.index("--listFiles") == -1)
    asserts.true(env, action.argv.index("--listEmittedFiles") == -1)
    asserts.true(env, action.argv.index("--traceResolution") == -1)
    asserts.true(env, action.argv.index("--diagnostics") == -1)
    asserts.true(env, action.argv.index("--extendedDiagnostics") == -1)
    return analysistest.end(env)

_verbose_false_test = analysistest.make(
    _verbose_false_test_impl,
    config_settings = { "@aspect_rules_ts//ts:verbose": "false" }
)


def _transition_impl(settings, attr):
    return {"@aspect_rules_ts//ts:verbose": 0}

configuration_transition = transition(
    implementation = _transition_impl,
    inputs = [],
    outputs = ["@aspect_rules_ts//ts:verbose"],
)

def _impll(ctx):
    return ctx.attr.target[0][DefaultInfo]

impl = rule(
    implementation = _impll,
    attrs = {
        "target": attr.label(mandatory = True, cfg = configuration_transition),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        )
    }
)

def ts_project_test_suite(name):
    """Test suite including all tests and data

    Args:
        name: Target name of the test_suite target.
    """
    _TSCONFIG = {
        "compilerOptions": {
            "declaration": True,
            "sourceMap": True,
        },
    }

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

    write_file(
        name = "supports_workers_explicitly_true_ts",
        out = "supports_workers_explicitly_true.ts",
        content = ["export const a = 1"],
        tags = ["manual"],
    )
    ts_project(
        name = "supports_workers_explicitly_true",
        srcs = ["supports_workers_explicitly_true.ts"],
        tsconfig = _TSCONFIG,
        tags = ["manual"],
        supports_workers = True
    )
    _supports_workers_explicitly_true_test(
        name = "supports_workers_explicitly_true_test",
        target_under_test = "supports_workers_explicitly_true",
    )


    write_file(
        name = "supports_workers_explicitly_false_ts",
        out = "supports_workers_explicitly_false.ts",
        content = ["export const a = 2"],
        tags = ["manual"],
    )
    ts_project(
        name = "supports_workers_explicitly_false",
        srcs = ["supports_workers_explicitly_false.ts"],
        tsconfig = _TSCONFIG,
        tags = ["manual"],
        supports_workers = False
    )
    _supports_workers_explicitly_false_test(
        name = "supports_workers_explicitly_false_test",
        target_under_test = "supports_workers_explicitly_false",
    )

    write_file(
        name = "supports_workers_implicitly_true_ts",
        out = "supports_workers_implicitly_true.ts",
        content = ["export const a = 3"],
        tags = ["manual"],
    )
    ts_project(
        name = "supports_workers_implicitly_true",
        srcs = ["supports_workers_implicitly_true.ts"],
        tsconfig = _TSCONFIG,
        tags = ["manual"]
    )
    _supports_workers_implicitly_true_test(
        name = "supports_workers_implicitly_true_test",
        target_under_test = ":supports_workers_implicitly_true",
    )

    write_file(
        name = "supports_workers_implicitly_false_ts",
        out = "supports_workers_implicitly_false.ts",
        content = ["export const a = 4"],
        tags = ["manual"],
    )
    ts_project(
        name = "supports_workers_implicitly_false",
        srcs = ["supports_workers_implicitly_false.ts"],
        tsconfig = _TSCONFIG,
        tags = ["manual"]
    )
    impl(
        name = "t",
        target = "supports_workers_implicitly_false"
    )
    _supports_workers_implicitly_false_test(
        name = "supports_workers_implicitly_false_test",
        target_under_test = ":t",
    )


    write_file(
        name = "verbose_true_ts",
        out = "verbose_true.ts",
        content = ["export const a = 5"],
        tags = ["manual"],
    )
    ts_project(
        name = "verbose_true",
        srcs = ["verbose_true.ts"],
        tsconfig = _TSCONFIG,
        tags = ["manual"]
    )
    # _verbose_true_test(
    #     name = "verbose_true_test",
    #     target_under_test = "verbose_true",
    # )


    write_file(
        name = "verbose_false_ts",
        out = "verbose_false.ts",
        content = ["export const a = 6"],
        tags = ["manual"],
    )
    ts_project(
        name = "verbose_false",
        srcs = ["verbose_false.ts"],
        tsconfig = _TSCONFIG,
        tags = ["manual"]
    )
    # _verbose_false_test(
    #     name = "verbose_false_test",
    #     target_under_test = "verbose_false",
    # )

    native.test_suite(
        name = name,
        tests = [
            ":dir_test",
            ":use_dir_test",
            ":supports_workers_explicitly_true_test",
            ":supports_workers_explicitly_false_test",
            ":supports_workers_implicitly_true_test",
            ":supports_workers_implicitly_false_test",
            # ":verbose_true_test",
            # ":verbose_false_test"
        ],
    )
