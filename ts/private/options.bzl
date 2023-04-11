"""A terminal rule collecting verbosity and worker support information"""

OptionsInfo = provider(
    doc = "Internal: Provider that carries verbosity and global worker support information.",
    fields = ["args", "verbose", "supports_workers"]
)

def _options_impl(ctx):
    verbose = ctx.attr.verbose
    
    # TODO(2.0): remove this
    if "VERBOSE_LOGS" in ctx.var.keys():
        # buildifier: disable=print
        print("Usage of --define=VERBOSE_LOGS=1 is deprecated. use --@aspect_rules_ts//ts:verbose=true flag instead.")

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
            "--skipLibCheck"
        )

    print(ctx.attr.skip_lib_check)
    return OptionsInfo(
        verbose = verbose,
        args = args,
        supports_workers = ctx.attr.supports_workers,
    )

options = rule(
    implementation = _options_impl,
    attrs = {
        "verbose": attr.bool(),
        "supports_workers": attr.bool(),
        "skip_lib_check": attr.bool(),
    }
)