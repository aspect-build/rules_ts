"Helper rule to check that ts_project attributes match tsconfig.json properties"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_file_to_bin_action", "copy_files_to_bin_actions")
load("@aspect_bazel_lib//lib:paths.bzl", "to_output_relative_path")
load(":ts_config.bzl", "TsConfigInfo")

def _tsconfig_inputs(ctx):
    """Returns all transitively referenced tsconfig files from "tsconfig" and "extends" attributes."""
    inputs = []
    if TsConfigInfo in ctx.attr.tsconfig:
        inputs.append(ctx.attr.tsconfig[TsConfigInfo].deps)
    else:
        inputs.append(depset([ctx.file.tsconfig]))
    if hasattr(ctx.attr, "extends") and ctx.attr.extends:
        if TsConfigInfo in ctx.attr.extends:
            inputs.append(ctx.attr.extends[TsConfigInfo].deps)
        else:
            inputs.append(ctx.attr.extends.files)
    return depset(transitive = inputs)

def _validate_action(ctx, tsconfig_inputs):
    # Bazel validation actions must still produce an output file.
    marker = ctx.actions.declare_file("%s_params.validation" % ctx.label.name)
    tsconfig = copy_file_to_bin_action(ctx, ctx.file.tsconfig)

    arguments = ctx.actions.args()
    config = struct(
        allow_js = ctx.attr.allow_js,
        declaration = ctx.attr.declaration,
        declaration_map = ctx.attr.declaration_map,
        preserve_jsx = ctx.attr.preserve_jsx,
        composite = ctx.attr.composite,
        no_emit = ctx.attr.no_emit,
        emit_declaration_only = ctx.attr.emit_declaration_only,
        resolve_json_module = ctx.attr.resolve_json_module,
        source_map = ctx.attr.source_map,
        incremental = ctx.attr.incremental,
        ts_build_info_file = ctx.attr.ts_build_info_file,
        isolated_typecheck = ctx.attr.isolated_typecheck,
        out_dir = ctx.attr.out_dir,
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
        inputs = copy_files_to_bin_actions(ctx, tsconfig_inputs),
        outputs = [marker],
        arguments = [arguments],
        mnemonic = "TsValidateOptions",
        env = {
            "BAZEL_BINDIR": ctx.bin_dir.path,
        },
    )

    return [marker]

lib = struct(
    tsconfig_inputs = _tsconfig_inputs,
    validation_action = _validate_action,
)
