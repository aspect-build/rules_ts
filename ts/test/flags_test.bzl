load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//ts:defs.bzl", "ts_project")

_ActionInfo = provider(fields = ["actions", "bin_path"],)

def _transition_impl(settings, attr):
    return {
        "@aspect_rules_ts//ts:supports_workers": attr.supports_workers,
        "@aspect_rules_ts//ts:verbose": attr.verbose,
        "@aspect_rules_ts//ts:skipLibCheck": attr.skip_lib_check
    }

configuration_transition = transition(
    implementation = _transition_impl,
    inputs = [],
    outputs = [
        "@aspect_rules_ts//ts:supports_workers",
        "@aspect_rules_ts//ts:verbose",
        "@aspect_rules_ts//ts:skipLibCheck"
    ],
)

def _transition_rule_impl(ctx):
    target = ctx.attr.target[0]
    return [
        target[DefaultInfo],
        _ActionInfo(actions = target.actions)
    ]

_transition_rule = rule(
    implementation = _transition_rule_impl,
    attrs = {
        "target": attr.label(mandatory = True, cfg = configuration_transition),
        "supports_workers": attr.bool(default = True),
        "verbose": attr.bool(default = False),
        "skip_lib_check": attr.string(default = "honor_tsconfig"),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        )
    }
)

def _find_tsc_action(env, target_under_test):    
    found_action = None
    actions = target_under_test.actions
    if _ActionInfo in target_under_test:
        actions =  target_under_test[_ActionInfo].actions
    for action in actions:
        if action.mnemonic == "TsProject":
            found_action = action
            break
    asserts.true(env, found_action != None, "could not find the TsProject action")
    return found_action

# explicit supports_workers = true
def _supports_workers_explicitly_true_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.true(env, action.argv[0].find("npm_typescript/tsc_worker.sh") != -1, "expected workers to be enabled explicitly.")
    return analysistest.end(env)

_supports_workers_explicitly_true_test = analysistest.make(_supports_workers_explicitly_true_test_impl)

# explicit supports_workers = false
def _supports_workers_explicitly_false_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.true(env, action.argv[0].find("npm_typescript/tsc.sh") != -1, "expected workers to be disabled explicitly.")
    return analysistest.end(env)

_supports_workers_explicitly_false_test = analysistest.make(_supports_workers_explicitly_false_test_impl)


# implicit supports_workers = true
def _supports_workers_implicitly_true_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.true(env, action.argv[0].find("npm_typescript/tsc_worker.sh") != -1, "expected workers to be enabled globally.")
    return analysistest.end(env)

_supports_workers_implicitly_true_test = analysistest.make(_supports_workers_implicitly_true_test_impl)

# implicit supports_workers = false
def _supports_workers_implicitly_false_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    action = _find_tsc_action(env, target_under_test)
    asserts.true(env, action.argv[0].find("npm_typescript/tsc.sh") != -1, "expected workers to be disabled globally.")
    return analysistest.end(env)

_supports_workers_implicitly_false_test = analysistest.make(_supports_workers_implicitly_false_test_impl)


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




def _ts_project_with_flags(name, supports_workers = None, supports_workers_flag = None, verbose_flag = None, skip_lib_check_flag = None, **kwargs):
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
        name = "supports_workers_explicitly_true",
        tsconfig = _TSCONFIG,
        supports_workers = True,
        # supports_workers should override the flag
        supports_workers_flag = False
    )
    _supports_workers_explicitly_true_test(
        name = "supports_workers_explicitly_true_test",
        target_under_test = ":supports_workers_explicitly_true",
    )

    _ts_project_with_flags(
        name = "supports_workers_explicitly_false",
        tsconfig = _TSCONFIG,
        supports_workers = False,
        # supports_workers should override the flag
        supports_workers_flag = True
    )
    _supports_workers_explicitly_false_test(
        name = "supports_workers_explicitly_false_test",
        target_under_test = ":supports_workers_explicitly_false",
    )


    _ts_project_with_flags(
        name = "supports_workers_implicitly_true",
        tsconfig = _TSCONFIG,
        # supports_workers attribute is not set explicitly so the flag should be respected
        supports_workers_flag = True
    )
    _supports_workers_implicitly_true_test(
        name = "supports_workers_implicitly_true_test",
        target_under_test = ":supports_workers_implicitly_true",
    )


    _ts_project_with_flags(
        name = "supports_workers_implicitly_false",
        tsconfig = _TSCONFIG,
        # supports_workers attribute is not set explicitly so the flag should be respected
        supports_workers_flag = False
    )
    _supports_workers_implicitly_false_test(
        name = "supports_workers_implicitly_false_test",
        target_under_test = ":supports_workers_implicitly_false",
    )


    _ts_project_with_flags(
        name = "verbose_true",
        tsconfig = _TSCONFIG,
        verbose_flag = True
    )
    _verbose_true_test(
        name = "verbose_true_test",
        target_under_test = ":verbose_true",
    )

    _ts_project_with_flags(
        name = "verbose_false",
        tsconfig = _TSCONFIG,
        verbose_flag = False
    )
    _verbose_false_test(
        name = "verbose_false_test",
        target_under_test = ":verbose_false",
    )


    _ts_project_with_flags(
        name = "skip_lib_check_always",
        tsconfig = _TSCONFIG,
        skip_lib_check_flag = "always"
    )
    _skip_lib_check_always_test(
        name = "skip_lib_check_always_test",
        target_under_test = ":skip_lib_check_always",
    )


    _ts_project_with_flags(
        name = "skip_lib_check_honor_tsconfig",
        tsconfig = _TSCONFIG,
        skip_lib_check_flag = "honor_tsconfig"
    )
    _skip_lib_check_honor_tsconfig_test(
        name = "skip_lib_check_honor_tsconfig_test",
        target_under_test = ":skip_lib_check_honor_tsconfig",
    )

    native.test_suite(
        name = name,
        tests = [
            ":supports_workers_explicitly_true_test",
            ":supports_workers_explicitly_false_test",
            ":supports_workers_implicitly_true_test",
            ":supports_workers_implicitly_false_test",
            ":verbose_true_test",
            ":verbose_false_test",
            ":skip_lib_check_always_test",
            ":skip_lib_check_honor_tsconfig_test"
        ],
    )
