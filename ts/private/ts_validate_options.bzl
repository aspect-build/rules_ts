"Helper rule to check that ts_project attributes match tsconfig.json properties"

load(":ts_config.bzl", "TsConfigInfo")
load(":ts_lib.bzl", "COMPILER_OPTION_ATTRS", "ValidOptionsInfo")
load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_files_to_bin_actions")

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

def _validate_options_impl(ctx):
    # Bazel won't run our action unless its output is needed, so make a marker file
    # We make it a .d.ts file so we can plumb it to the deps of the ts_project compile.
    marker = ctx.actions.declare_file("%s.optionsvalid.d.ts" % ctx.label.name)

    arguments = ctx.actions.args()
    config = struct(
        allow_js = ctx.attr.allow_js,
        declaration = ctx.attr.declaration,
        declaration_map = ctx.attr.declaration_map,
        preserve_jsx = ctx.attr.preserve_jsx,
        composite = ctx.attr.composite,
        emit_declaration_only = ctx.attr.emit_declaration_only,
        resolve_json_module = ctx.attr.resolve_json_module,
        source_map = ctx.attr.source_map,
        incremental = ctx.attr.incremental,
        ts_build_info_file = ctx.attr.ts_build_info_file,
    )
    arguments.add_all([ctx.file.tsconfig.short_path, marker.short_path, ctx.attr.target, json.encode(config)])

    inputs = _tsconfig_inputs(ctx)

    ctx.actions.run(
        executable = ctx.executable.validator,
        inputs = copy_files_to_bin_actions(ctx, inputs.to_list()),
        outputs = [marker],
        arguments = [arguments],
        mnemonic = "TsValidateOptions",
        env = {
            "BAZEL_BINDIR": ctx.bin_dir.path,
        },
    )

    return [
        ValidOptionsInfo(marker = marker),
    ]

_ATTRS = dict(COMPILER_OPTION_ATTRS, **{
    "target": attr.string(),
    "ts_build_info_file": attr.string(),
    "tsconfig": attr.label(mandatory = True, allow_single_file = [".json"]),
    "validator": attr.label(mandatory = True, executable = True, cfg = "exec"),
})

lib = struct(
    attrs = _ATTRS,
    implementation = _validate_options_impl,
    tsconfig_inputs = _tsconfig_inputs,
)
