"""Toolchain rule carrying the TypeScript compiler for the exec platform.

Two flavors exist:

- Native TypeScript versions (7+) publish the compiler as a Go binary in
  platform-specific npm packages such as `@typescript/typescript-darwin-arm64`,
  invoked directly without NodeJS. The binary locates the bundled `lib.*.d.ts`
  default libraries relative to its own (symlink-resolved) location, so those
  files must accompany the binary and stay siblings of it.

- Older versions ship the compiler as JavaScript, wrapped in a NodeJS-hosted
  `js_binary`.
"""

TSC_TOOLCHAIN_TYPE = "@aspect_rules_ts//ts:toolchain_type"

TscInfo = provider(
    doc = "Information about how to invoke the TypeScript compiler.",
    fields = {
        "is_native": "Whether tsc is a native (7+) pre-compiled binary, invoked without NodeJS.",
        "tsc": """The TypeScript compiler for the exec platform.

A File (the pre-compiled executable) when is_native, otherwise a
FilesToRunProvider (the NodeJS-hosted js_binary). Both forms are accepted as
the `executable` of `ctx.actions.run`.""",
        "tool_files": """depset of Files required to run the native tsc.

Includes the executable itself along with the bundled lib.*.d.ts default
libraries which must remain siblings of the binary. Empty unless is_native.""",
        "env": """dict of environment variables the compiler requires on its actions.

Values may contain the `$(BINDIR)` placeholder, which consumers expand to the
output bin directory of the consuming action's configuration. The NodeJS-hosted
compiler requires `BAZEL_BINDIR` (a rules_js js_binary launcher convention);
the native binary requires nothing.""",
    },
)

def _tsc_toolchain_impl(ctx):
    if bool(ctx.attr.tsc) == bool(ctx.attr.tsc_binary):
        fail("tsc_toolchain: exactly one of 'tsc' (native binary) or 'tsc_binary' (NodeJS-hosted) must be set.")

    if ctx.attr.tsc:
        tool_files = depset([ctx.file.tsc], transitive = [depset(ctx.files.data)])
        tsc_path = ctx.file.tsc.path
        env = dict(ctx.attr.env)
        tscinfo = TscInfo(
            is_native = True,
            tsc = ctx.file.tsc,
            tool_files = tool_files,
            env = env,
        )
        default = DefaultInfo(
            files = tool_files,
            runfiles = ctx.runfiles(transitive_files = tool_files),
        )
    else:
        tsc_binary = ctx.attr.tsc_binary[DefaultInfo].files_to_run
        tsc_path = tsc_binary.executable.path

        # The rules_js js_binary launcher requires BAZEL_BINDIR in the environment
        # and chdirs to it before spawning the program.
        env = dict({"BAZEL_BINDIR": "$(BINDIR)"}, **ctx.attr.env)
        tscinfo = TscInfo(
            is_native = False,
            tsc = tsc_binary,
            tool_files = depset(),
            env = env,
        )
        default = DefaultInfo(
            files = depset([tsc_binary.executable]),
        )

    # Make the $(TSC_BINARY_PATH) variable available in places like genrules.
    # See https://docs.bazel.build/versions/main/be/make-variables.html#custom_variables
    template_variables = platform_common.TemplateVariableInfo({
        "TSC_BINARY_PATH": tsc_path,
    })

    # Consumers reach the compiler through ctx.toolchains[TSC_TOOLCHAIN_TYPE].tscinfo.
    toolchain_info = platform_common.ToolchainInfo(
        tscinfo = tscinfo,
        template_variables = template_variables,
        default = default,
    )
    return [
        default,
        toolchain_info,
        # Also provided directly so a target can be referenced by the
        # ts_project(tsc_toolchain) attribute, outside of toolchain resolution.
        tscinfo,
        template_variables,
    ]

tsc_toolchain = rule(
    implementation = _tsc_toolchain_impl,
    attrs = {
        "tsc": attr.label(
            doc = "A hermetically downloaded native `tsc` executable for the exec platform.",
            allow_single_file = True,
        ),
        "data": attr.label_list(
            doc = "Files required at runtime by the native compiler, such as the bundled lib.*.d.ts default libraries.",
            allow_files = True,
        ),
        "tsc_binary": attr.label(
            doc = "A NodeJS-hosted `tsc` for TypeScript versions that ship the compiler as JavaScript.",
            executable = True,
            cfg = "exec",
        ),
        "env": attr.string_dict(
            doc = """Additional environment variables to set on compiler actions.

            Values may contain the `$(BINDIR)` placeholder which is expanded to the
            output bin directory of the consuming action's configuration.""",
        ),
    },
    doc = """Defines a TypeScript compiler toolchain.

For usage see https://docs.bazel.build/versions/main/toolchains.html#defining-toolchains.
""",
)
