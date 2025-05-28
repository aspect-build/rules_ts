"Test for ts_project() flags"

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//ts:defs.bzl", "ts_project")

_ActionInfo = provider("test provider", fields = ["actions", "bin_path"])

def _transition_impl(_settings, attr):
    return {
        "@aspect_rules_ts//ts:supports_workers": attr.supports_workers,
        "@aspect_rules_ts//ts:verbose": attr.verbose,
        "@aspect_rules_ts//ts:skipLibCheck": attr.skip_lib_check,
        "@aspect_rules_ts//ts:generate_tsc_trace": attr.generate_tsc_trace,
    }

configuration_transition = transition(
    implementation = _transition_impl,
    inputs = [],
    outputs = [
        "@aspect_rules_ts//ts:supports_workers",
        "@aspect_rules_ts//ts:verbose",
        "@aspect_rules_ts//ts:skipLibCheck",
        "@aspect_rules_ts//ts:generate_tsc_trace",
    ],
)

def _transition_rule_impl(ctx):
    target = ctx.attr.target[0]
    return [
        target[DefaultInfo],
        _ActionInfo(actions = target.actions),
    ]

_transition_rule = rule(
    implementation = _transition_rule_impl,
    attrs = {
        "target": attr.label(mandatory = True, cfg = configuration_transition),
        "supports_workers": attr.bool(default = True),
        "verbose": attr.bool(default = False),
        "skip_lib_check": attr.string(default = "honor_tsconfig"),
        "generate_tsc_trace": attr.bool(default = False),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _find_tsc_action(env, target_under_test):
    found_action = None
    actions = target_under_test.actions
    if _ActionInfo in target_under_test:
        actions = target_under_test[_ActionInfo].actions
    for action in actions:
        if action.mnemonic == "TsProject":
            found_action = action
            break
    asserts.true(env, found_action != None, "could not find the TsProject action")
    return found_action

# verbose flag = true test
def _verbose_true_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.true(env, "--listFiles" in action.argv)
    asserts.true(env, "--listEmittedFiles" in action.argv)
    asserts.true(env, "--traceResolution" in action.argv)
    asserts.true(env, "--diagnostics" in action.argv)
    asserts.true(env, "--extendedDiagnostics" in action.argv)
    return analysistest.end(env)

_verbose_true_test = analysistest.make(_verbose_true_test_impl)

# verbose flag = false test
def _verbose_false_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.false(env, "--listFiles" in action.argv)
    asserts.false(env, "--listEmittedFiles" in action.argv)
    asserts.false(env, "--traceResolution" in action.argv)
    asserts.false(env, "--diagnostics" in action.argv)
    asserts.false(env, "--extendedDiagnostics" in action.argv)
    return analysistest.end(env)

_verbose_false_test = analysistest.make(_verbose_false_test_impl)

# skipLibCheck flag = always test
def _skip_lib_check_always_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.true(env, "--skipLibCheck" in action.argv, "expected --skipLibCheck to be set")
    return analysistest.end(env)

_skip_lib_check_always_test = analysistest.make(_skip_lib_check_always_test_impl)

# skipLibCheck flag = honor_tsconfig test
def _skip_lib_check_honor_tsconfig_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.false(env, "--skipLibCheck" in action.argv, "expected --skipLibCheck to be not set")
    return analysistest.end(env)

_skip_lib_check_honor_tsconfig_test = analysistest.make(_skip_lib_check_honor_tsconfig_test_impl)

# generate_tsc_trace flag = true test
def _generate_tsc_trace_true_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.true(env, "--generateTrace" in action.argv, "expected --generateTrace to be set")
    return analysistest.end(env)

_generate_tsc_trace_true_test = analysistest.make(_generate_tsc_trace_true_test_impl)

# generate_tsc_trace flag = false test
def _generate_tsc_trace_false_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.false(env, "--generateTrace" in action.argv, "expected --generateTrace to not be set")
    return analysistest.end(env)

_generate_tsc_trace_false_test = analysistest.make(_generate_tsc_trace_false_test_impl)

def _ts_project_with_flags(name, supports_workers = None, supports_workers_flag = None, verbose_flag = None, skip_lib_check_flag = None, generate_tsc_trace_flag = None, **kwargs):
    write_file(
        name = "{}_write".format(name),
        out = "{}.ts".format(name),
        content = ["const a = 1;"],
        tags = ["manual"],
    )
    ts_project(
        name = "{}_ts".format(name),
        srcs = ["{}.ts".format(name)],
        tags = ["manual"],
        supports_workers = supports_workers,
        **kwargs
    )
    _transition_rule(
        name = name,
        target = "{}_ts".format(name),
        supports_workers = supports_workers_flag,
        verbose = verbose_flag,
        skip_lib_check = skip_lib_check_flag,
        generate_tsc_trace = generate_tsc_trace_flag,
    )

def ts_project_flags_test_suite(name):
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

    _ts_project_with_flags(
        name = "verbose_true",
        tsconfig = _TSCONFIG,
        verbose_flag = True,
    )
    _verbose_true_test(
        name = "verbose_true_test",
        target_under_test = ":verbose_true",
    )

    _ts_project_with_flags(
        name = "verbose_false",
        tsconfig = _TSCONFIG,
        verbose_flag = False,
    )
    _verbose_false_test(
        name = "verbose_false_test",
        target_under_test = ":verbose_false",
    )

    _ts_project_with_flags(
        name = "skip_lib_check_always",
        tsconfig = _TSCONFIG,
        skip_lib_check_flag = "always",
    )
    _skip_lib_check_always_test(
        name = "skip_lib_check_always_test",
        target_under_test = ":skip_lib_check_always",
    )

    _ts_project_with_flags(
        name = "skip_lib_check_honor_tsconfig",
        tsconfig = _TSCONFIG,
        skip_lib_check_flag = "honor_tsconfig",
    )
    _skip_lib_check_honor_tsconfig_test(
        name = "skip_lib_check_honor_tsconfig_test",
        target_under_test = ":skip_lib_check_honor_tsconfig",
    )

    _ts_project_with_flags(
        name = "generate_tsc_trace_true",
        tsconfig = _TSCONFIG,
        generate_tsc_trace_flag = True,
    )
    _generate_tsc_trace_true_test(
        name = "generate_tsc_trace_true_test",
        target_under_test = ":generate_tsc_trace_true",
    )

    _ts_project_with_flags(
        name = "generate_tsc_trace_false",
        tsconfig = _TSCONFIG,
        generate_tsc_trace_flag = False,
    )
    _generate_tsc_trace_false_test(
        name = "generate_tsc_trace_false_test",
        target_under_test = ":generate_tsc_trace_false",
    )

    native.test_suite(
        name = name,
        tests = [
            ":verbose_true_test",
            ":verbose_false_test",
            ":skip_lib_check_always_test",
            ":skip_lib_check_honor_tsconfig_test",
            ":generate_tsc_trace_true_test",
            ":generate_tsc_trace_false_test",
        ],
    )
