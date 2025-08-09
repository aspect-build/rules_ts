"""A terminal rule collecting verbosity and worker support information"""

transpiler_selection_required = """\

######## Required Transpiler Selection ########

You must select a transpiler for ts_project rules, which produces the .js outputs.

Please read https://docs.aspect.build/rules/aspect_rules_ts/docs/transpiler

##########################################################
"""

skip_lib_check_selection_required = """

######## Required Typecheck Performance Selection ########

TypeScript's type-checking exposes a flag `--skipLibCheck`:
https://www.typescriptlang.org/tsconfig#skipLibCheck

Using this flag saves substantial time during type-checking.
Rather than doing a full check of all d.ts files, TypeScript will only type-check the code you
specifically refer to in your app's source code.
We recommend this for most rules_ts users.

HOWEVER this performance improvement comes at the expense of type-system accuracy. 
For example, two packages could define two copies of the same type in an inconsistent way.
If you publish a library from your repository, your incorrect types may result in errors for your users.

You must choose exactly one of the following flags:

1. To choose the faster performance put this in /.bazelrc:

    # passes an argument `--skipLibCheck` to *every* spawn of tsc
    # Bazel 6.4 or greater: 'common' means 'any command that supports this flag'
    common --@aspect_rules_ts//ts:skipLibCheck=always

    # Between Bazel 6.0 and 6.3, you need all of this, to avoid discarding the analysis cache:
    build --@aspect_rules_ts//ts:skipLibCheck=always
    fetch --@aspect_rules_ts//ts:skipLibCheck=always
    query --@aspect_rules_ts//ts:skipLibCheck=always

    # Before Bazel 6.0, only the 'build' and 'fetch' lines work.

2. To choose more correct typechecks, put this in /.bazelrc:

    # honor the setting of `skipLibCheck` in the tsconfig.json file
    # Bazel 6.4 or greater: 'common' means 'any command that supports this flag'
    common --@aspect_rules_ts//ts:skipLibCheck=honor_tsconfig

    # Between Bazel 6.0 and 6.3, you need all of this, to avoid discarding the analysis cache:
    build --@aspect_rules_ts//ts:skipLibCheck=honor_tsconfig
    fetch --@aspect_rules_ts//ts:skipLibCheck=honor_tsconfig
    query --@aspect_rules_ts//ts:skipLibCheck=honor_tsconfig

    # Before Bazel 6.0, only the 'build' and 'fetch' lines work.

##########################################################
"""

OptionsInfo = provider(
    doc = "Internal: Provider that carries verbosity and global worker support information.",
    fields = ["args", "default_to_tsc_transpiler", "verbose", "supports_workers", "generate_tsc_trace", "validation_typecheck"],
)

def _options_impl(ctx):
    verbose = ctx.attr.verbose

    args = []

    # When users report problems, we can ask them to re-build with
    # --@aspect_rules_ts//ts:verbose=true
    # so anything that's useful to diagnose rule failures belongs here
    if verbose:
        args = [
            # What files were in the ts.Program
            "--listFiles",
            # Did tsc write all outputs to the place we expect to find them?
            "--listEmittedFiles",
            # Why did module resolution fail?
            "--traceResolution",
            # Why was the build slow?
            "--diagnostics",
            "--extendedDiagnostics",
        ]

    is_root_module = ctx.label.workspace_root == ""
    if is_root_module and ctx.attr.skip_lib_check == "":
        fail(skip_lib_check_selection_required)

    if ctx.attr.skip_lib_check == "always":
        args.append(
            "--skipLibCheck",
        )

    return OptionsInfo(
        verbose = verbose,
        args = args,
        supports_workers = ctx.attr.supports_workers,
        default_to_tsc_transpiler = ctx.attr.default_to_tsc_transpiler,
        generate_tsc_trace = ctx.attr.generate_tsc_trace,
        validation_typecheck = ctx.attr.validation_typecheck,
    )

options = rule(
    implementation = _options_impl,
    attrs = {
        "default_to_tsc_transpiler": attr.bool(),
        "verbose": attr.bool(),
        "supports_workers": attr.bool(),
        "skip_lib_check": attr.string(),
        "generate_tsc_trace": attr.bool(),
        "validation_typecheck": attr.bool(),
    },
)
