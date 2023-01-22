"""A terminal rule collecting verbosity and worker support information"""

ConfigurationInfo = provider(
    doc = "Internal: Provider that carries verbosity and global worker support information.",
    fields = ["verbosity_args", "verbose", "supports_workers"]
)

def _configuration_impl(ctx):
    verbose = ctx.attr.verbose
    
    # TODO(2.0): remove this
    if "VERBOSE_LOGS" in ctx.var.keys():
        # buildifier: disable=print
        print("Usage of --define=VERBOSE_LOGS=1 is deprecated. use --@aspect_rules_ts//ts:verbose=true flag instead.")

    verbosity_args = []

    if verbose:
        verbosity_args = [
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

    return ConfigurationInfo(
        verbose = verbose,
        verbosity_args = verbosity_args,
        supports_workers = ctx.attr.supports_workers,
    )

configuration = rule(
    implementation = _configuration_impl,
    attrs = {
        "verbose": attr.bool(),
        "supports_workers": attr.bool(),
    }
)