"Helper rule to check that ts_project attributes match tsconfig.json properties"

load("@aspect_bazel_lib//lib:paths.bzl", "to_output_relative_path")

def _validate_action(ctx, tsconfig, tsconfig_deps):
    """Create an action to validate the ts_project attributes against the tsconfig.json properties.

Assumes all tsconfig file deps are already copied to the bin directory.
"""

    # Bazel validation actions must still produce an output file.
    marker = ctx.actions.declare_file("%s_params.validation" % ctx.label.name)

    arguments = ctx.actions.args()
    config = struct(
        allow_js = ctx.attr.allow_js,
        declaration = ctx.attr.declaration,
        declaration_map = ctx.attr.declaration_map,
        out_dir = ctx.attr.out_dir,
        preserve_jsx = ctx.attr.preserve_jsx,
        composite = ctx.attr.composite,
        no_emit = ctx.attr.no_emit,
        emit_declaration_only = ctx.attr.emit_declaration_only,
        resolve_json_module = ctx.attr.resolve_json_module,
        source_map = ctx.attr.source_map,
        incremental = ctx.attr.incremental,
        ts_build_info_file = ctx.attr.ts_build_info_file,
        isolated_typecheck = ctx.attr.isolated_typecheck,
        root_dir = ctx.attr.root_dir,
    )
    arguments.add_all([
        to_output_relative_path(tsconfig),
        to_output_relative_path(marker),
        str(ctx.label),
        ctx.label.package,
        json.encode(config),
    ])

    ctx.actions.run(
        executable = ctx.executable.validator,
        inputs = tsconfig_deps,
        outputs = [marker],
        arguments = [arguments],
        mnemonic = "TsValidateOptions",
        env = {
            "BAZEL_BINDIR": ctx.bin_dir.path,
        },
    )

    return [marker]

lib = struct(
    validation_action = _validate_action,
)
