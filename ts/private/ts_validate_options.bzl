"Helper rule to check that ts_project attributes match tsconfig.json properties"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_file_to_bin_action", "copy_files_to_bin_actions")
load("@aspect_bazel_lib//lib:paths.bzl", "to_output_relative_path")
load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load(":ts_config.bzl", "TsConfigInfo")
load(":ts_lib.bzl", "COMPILER_OPTION_ATTRS")

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
    tsconfig = copy_file_to_bin_action(ctx, ctx.file.tsconfig)

    # Provider validation
    if not ctx.attr.allow_js:
        for d in ctx.attr.deps:
            if not d[JsInfo].declarations:
                fail("""\
ts_project '{1}' dependency '{0}' does does not contain any declarations (.d.ts or other type-check files).
Generally, targets which produce no declarations aren't useful as dependencies to the TypeScript type-checker.
This likely means you forgot to set 'declaration = true' in the compilerOptions for that target.

To disable this check, set the validate attribute to False:
  npx @bazel/buildozer 'set validate False' {1}
""".format(d.label, ctx.attr.target))

    # External validation
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
    arguments.add_all([
        to_output_relative_path(tsconfig),
        to_output_relative_path(marker),
        ctx.attr.target,
        json.encode(config),
    ])

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
        OutputGroupInfo(_validation = depset([marker])),
    ]

_ATTRS = dict(COMPILER_OPTION_ATTRS, **{
    "deps": attr.label_list(mandatory = True, providers = [JsInfo]),
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
