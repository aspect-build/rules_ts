"SWC rule for producing isolated declarations"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "COPY_FILE_TO_BIN_TOOLCHAINS", "copy_files_to_bin_actions")
load("@aspect_rules_js//js:providers.bzl", "js_info")

# buildifier: disable=bzl-visibility
load("@aspect_rules_swc//swc/private:swc.bzl", _swc_lib = "swc")

# buildifier: disable=bzl-visibility
load("//ts/private:ts_lib.bzl", _lib = "lib")

def _swc_action(ctx, swc_binary, **kwargs):
    ctx.actions.run(
        mnemonic = "SWCCompile",
        progress_message = "Compiling %{label} [swc %{input}]",
        executable = swc_binary,
        **kwargs
    )

def _swc_decls_impl(ctx):
    [declaration, composite, allow_js] = [True, False, False]
    srcs_inputs = copy_files_to_bin_actions(ctx, ctx.files.srcs)
    src_paths = [_lib.relative_to_package(src.path, ctx) for src in srcs_inputs]
    typings_outs = _lib.declare_outputs(ctx, _lib.calculate_typings_outs(src_paths, ctx.attr.out_dir, ctx.attr.root_dir, declaration, composite, allow_js))
    # typing_maps_outs = _lib.calculate_typing_maps_outs(ctx.attr.srcs, ctx.attr.out_dir, ctx.attr.root_dir, declaration_map, allow_js)

    swc_toolchain = ctx.toolchains["@aspect_rules_swc//swc:toolchain_type"]

    inputs = swc_toolchain.swcinfo.tool_files[:]
    inputs.extend(srcs_inputs)

    args = ctx.actions.args()
    args.add("compile")

    # Add user specified arguments *before* rule supplied arguments
    args.add_all(ctx.attr.args)

    args.add("--out-dir", ".")
    if ctx.attr.swcrc:
        args.add("--config-file", ctx.file.swcrc)
        inputs.append(ctx.file.swcrc)

    #for src in ctx.files.srcs:
    _swc_action(
        ctx,
        swc_toolchain.swcinfo.swc_binary,
        inputs = inputs,
        arguments = [
            args,
            srcs_inputs[0].path,
        ],
        outputs = typings_outs,
    )

    return [
        DefaultInfo(files = depset(typings_outs)),
        js_info(
            target = ctx.label,
            types = depset(typings_outs),
            transitive_types = depset(typings_outs),
        ),
    ]

swc_decls = rule(
    implementation = _swc_decls_impl,
    # TODO: add pre-declared outputs as well
    attrs = _swc_lib.attrs,
    toolchains = _swc_lib.toolchains + COPY_FILE_TO_BIN_TOOLCHAINS,
)
