"""A terminal rule collecting verbosity and worker support information"""

transpiler_selection_required = """\

######## Required Transpiler Selection ########

You must select a transpiler for ts_project rules, which produces the .js outputs.

Please read https://docs.aspect.build/rules/aspect_rules_ts/docs/transpiler

##########################################################
"""

OptionsInfo = provider(
    doc = "Internal: Provider that carries verbosity and global worker support information.",
    fields = ["args", "default_to_tsc_transpiler", "verbose", "supports_workers", "generate_tsc_trace"],
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

    if ctx.attr.skip_lib_check:
        args.append(
            "--skipLibCheck",
        )

    return OptionsInfo(
        verbose = verbose,
        args = args,
        supports_workers = ctx.attr.supports_workers,
        default_to_tsc_transpiler = ctx.attr.default_to_tsc_transpiler,
        generate_tsc_trace = ctx.attr.generate_tsc_trace,
    )

options = rule(
    implementation = _options_impl,
    attrs = {
        "default_to_tsc_transpiler": attr.bool(),
        "verbose": attr.bool(),
        "supports_workers": attr.bool(),
        "skip_lib_check": attr.bool(),
        "generate_tsc_trace": attr.bool(),
    },
)
