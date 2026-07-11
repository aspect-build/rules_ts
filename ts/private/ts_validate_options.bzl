"Helper rule to check that ts_project attributes match tsconfig.json properties"

load("@bazel_lib//lib:paths.bzl", "relative_file", "to_output_relative_path")

def _bool_arg(value):
    return "true" if value else "false"

def _package_dir(ctx):
    if ctx.label.workspace_root and ctx.label.package:
        return ctx.label.workspace_root + "/" + ctx.label.package
    return ctx.label.workspace_root or ctx.label.package

def _tsconfig_package_relative_dir(ctx, tsconfig):
    """The directory of the tsconfig relative to the package, or None if outside the package.

    The empty string means the tsconfig sits in the package directory itself.
    """
    short_path = tsconfig.short_path
    root_relative = "external/" + short_path[3:] if short_path.startswith("../") else short_path
    tsconfig_dir = root_relative[:root_relative.rfind("/")] if "/" in root_relative else ""
    package_dir = _package_dir(ctx)
    if tsconfig_dir == package_dir:
        return ""
    if package_dir:
        if tsconfig_dir.startswith(package_dir + "/"):
            return tsconfig_dir[len(package_dir) + 1:]
    elif not tsconfig_dir.startswith("external/"):
        return tsconfig_dir
    return None

def _validate_action(ctx, tsconfig, tsconfig_deps):
    """Create an action to validate the ts_project attributes against the tsconfig.json properties.

    The single action writes a wrapper tsconfig, resolves the extends chain
    with `tsc --showConfig`, and validates the attributes against the result.

Assumes all tsconfig file deps are already copied to the bin directory.
"""
    tsconfig_dir = _tsconfig_package_relative_dir(ctx, tsconfig)

    # A wrapper tsconfig extending the project's tsconfig: `files` suppresses
    # the TS18003 error tsc otherwise raises because srcs are not inputs to
    # this action. The script writes it (a declared output, so this works on
    # executors with read-only input trees).
    #
    # The wrapper sits in the same directory as the tsconfig whenever that
    # directory is within the package, because `${configDir}` (TypeScript 5.5+)
    # resolves to the directory of the config tsc was invoked on: the wrapper
    # must be invoked from where the compile action invokes the real tsconfig.
    # A tsconfig from another package cannot be colocated (outputs may only be
    # declared below the package); its wrapper sits in the package directory,
    # where `${configDir}` may resolve differently than at compile time.
    wrapper_name = "%s_showconfig_tsconfig.json" % ctx.label.name
    if tsconfig_dir:
        wrapper_name = tsconfig_dir + "/" + wrapper_name
    wrapper = ctx.actions.declare_file(wrapper_name)
    extends = relative_file(tsconfig.path, wrapper.path)
    if not extends.startswith("."):
        extends = "./" + extends

    # The validation output is the resolved tsconfig itself: `tsc --showConfig`
    # output, the contract pinned by the dir_resolved_tsconfig_test golden.
    resolved = ctx.actions.declare_file("%s.resolved.tsconfig.json" % ctx.label.name)

    jq = ctx.toolchains["@jq.bzl//jq/toolchain:type"].jqinfo.bin

    # Mirror which tsconfig directory options the compile action overrides on
    # the tsc command line (see the tsc action in ts_project.bzl): overridden
    # options need not functionally agree with the attribute, since the
    # attribute wins at compile time.
    out_dir_overridden = bool(ctx.attr.out_dir or ctx.attr.root_dir)
    declaration_dir_overridden = out_dir_overridden and (ctx.attr.declaration or ctx.attr.composite)
    ts_build_info_file_overridden = bool(ctx.outputs.buildinfo_out)

    arguments = ctx.actions.args()
    arguments.add(ctx.file._validator)
    arguments.add(jq)
    arguments.add(ctx.executable._validation_tsc)
    arguments.add(to_output_relative_path(wrapper))
    arguments.add(extends)
    arguments.add(resolved)
    arguments.add(str(ctx.label))
    arguments.add(tsconfig_dir or "")
    arguments.add("allow_js=%s" % _bool_arg(ctx.attr.allow_js))
    arguments.add("composite=%s" % _bool_arg(ctx.attr.composite))
    arguments.add("declaration=%s" % _bool_arg(ctx.attr.declaration))
    arguments.add("declaration_dir=%s" % ctx.attr.declaration_dir)
    arguments.add("declaration_dir_overridden=%s" % _bool_arg(declaration_dir_overridden))
    arguments.add("declaration_map=%s" % _bool_arg(ctx.attr.declaration_map))
    arguments.add("emit_declaration_only=%s" % _bool_arg(ctx.attr.emit_declaration_only))
    arguments.add("incremental=%s" % _bool_arg(ctx.attr.incremental))
    arguments.add("isolated_typecheck=%s" % _bool_arg(ctx.attr.isolated_typecheck))
    arguments.add("no_emit=%s" % _bool_arg(ctx.attr.no_emit))
    arguments.add("out_dir=%s" % ctx.attr.out_dir)
    arguments.add("out_dir_overridden=%s" % _bool_arg(out_dir_overridden))
    arguments.add("preserve_jsx=%s" % _bool_arg(ctx.attr.preserve_jsx))
    arguments.add("resolve_json_module=%s" % _bool_arg(ctx.attr.resolve_json_module))
    arguments.add("root_dir=%s" % ctx.attr.root_dir)
    arguments.add("source_map=%s" % _bool_arg(ctx.attr.source_map))
    arguments.add("ts_build_info_file=%s" % ctx.attr.ts_build_info_file)
    arguments.add("ts_build_info_file_overridden=%s" % _bool_arg(ts_build_info_file_overridden))

    ctx.actions.run_shell(
        inputs = depset([ctx.file._validator], transitive = [tsconfig_deps]),
        outputs = [wrapper, resolved],
        tools = [ctx.executable._validation_tsc, jq],
        command = 'bash "$@"',
        arguments = [arguments],
        mnemonic = "TsValidateOptions",
        progress_message = "Validating TsConfig %{label}",
        env = {
            # tsc is a js_binary which runs in BAZEL_BINDIR
            "BAZEL_BINDIR": ctx.bin_dir.path,
        },
        use_default_shell_env = True,
    )

    return [resolved]

lib = struct(
    validation_action = _validate_action,
)
