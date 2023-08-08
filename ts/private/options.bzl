"""A terminal rule collecting verbosity and worker support information"""

transpiler_selection_required = """\

######## Required Transpiler Selection ########

You must select a transpiler for ts_project rules, which produces the .js outputs.
For more information, see https://docs.aspect.build/rules/aspect_rules_ts/docs/transpiler

1. Use [SWC](https://swc.rs/) for transpiles (recommended)

    This option results in the fastest development round-trip time, however it may have subtle
    compatibility issues: https://github.com/aspect-build/rules_ts/discussions/398

    Add rules_swc to your Bazel project, following instructions on a recent release:
    https://github.com/aspect-build/rules_swc/releases

    If you don't need any .swcrc, you can run these commands to fixup your `ts_project` calls:

        npx @bazel/buildozer 'fix movePackageToTop' //...:__pkg__
        npx @bazel/buildozer 'new_load @aspect_rules_swc//swc:defs.bzl swc' //...:__pkg__
        npx @bazel/buildozer 'set transpiler swc' //...:%ts_project
        npx @bazel/buildozer 'fix unusedLoads' //...:__pkg__
    
    To use an .swcrc file, see option 3 below.

2. Use [tsc](https://www.typescriptlang.org/docs/handbook/compiler-options.html):

    In rules_ts 1.x, the default value is to have TypeScript do both type-checking and transpilation.
    However, this is the slowest choice, and we no longer recommend this.

    Note that rules_ts used to recommend a "Persistent Worker" mode to keep the `tsc` process running
    as a background daemon, however this introduces correctness issues in the build and is no longer
    recommended.

    Add this to /.bazelrc:

        # Use "tsc" as the transpiler when ts_project has no `transpiler` set.
        build --@aspect_rules_ts//ts:default_to_tsc_transpiler

3. Use a custom transpiler

    You can set the `transpiler` attribute of each `ts_project` to any rule or macro.
    This could be swc with some custom arguments, babel, esbuild, or any other tool.

    You may want to create a `ts_project` macro within your repository where your choice is setup,
    then load() from your own macro rather than from @aspect_rules_ts.

##########################################################
"""

OptionsInfo = provider(
    doc = "Internal: Provider that carries verbosity and global worker support information.",
    fields = ["args", "default_to_tsc_transpiler", "verbose", "supports_workers"],
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
            "--skipLibCheck",
        )

    return OptionsInfo(
        verbose = verbose,
        args = args,
        supports_workers = ctx.attr.supports_workers,
        default_to_tsc_transpiler = ctx.attr.default_to_tsc_transpiler,
    )

options = rule(
    implementation = _options_impl,
    attrs = {
        "default_to_tsc_transpiler": attr.bool(),
        "verbose": attr.bool(),
        "supports_workers": attr.bool(),
        "skip_lib_check": attr.bool(),
    },
)
