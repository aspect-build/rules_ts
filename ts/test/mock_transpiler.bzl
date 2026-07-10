"Fixture to demonstrate a custom transpiler for ts_project"

load("@aspect_rules_ts//ts/private:ts_lib.bzl", "lib")

_DUMMY_SOURCEMAP = """{"version":3,"sources":["%s"],"mappings":"AAAO,KAAK,CAAC","file":"in.js","sourcesContent":["fake"]}"""

def _mock_impl(ctx):
    src_files = [src for src in ctx.files.srcs if src.short_path.endswith(".ts") and not src.short_path.endswith(".d.ts")]
    src_paths = lib.files_relative_to_package(ctx, src_files)
    out_files = []

    for src, src_path in zip(src_files, src_paths):
        js_file = ctx.actions.declare_file(src_path.replace(".ts", ".js"))
        map_file = ctx.actions.declare_file(src_path.replace(".ts", ".js.map"))

        out_files.append(js_file)
        out_files.append(map_file)

        ctx.actions.run_shell(
            inputs = [src],
            outputs = [js_file],
            command = "cp $@",
            arguments = [src.path, js_file.path.replace(".ts", ".js")],
        )

        ctx.actions.write(
            output = map_file,
            content = _DUMMY_SOURCEMAP % src.short_path,
        )

    return DefaultInfo(files = depset(out_files))

mock_impl = rule(
    attrs = {
        "srcs": attr.label_list(
            doc = "TypeScript source files",
            allow_files = True,
            mandatory = True,
        ),
        "js_outs": attr.output_list(),
        "map_outs": attr.output_list(),
    },
    implementation = _mock_impl,
)

def mock(name, srcs, source_map = False, **kwargs):
    # Calculate pre-declared outputs so they can be referenced as targets.
    # This is an optional transpiler feature aligning with the default tsc transpiler.
    outs = lib.calculate_outs(
        srcs = srcs,
        out_dir = None,
        typings_out_dir = None,
        root_dir = None,
        allow_js = False,
        resolve_json_module = False,
        preserve_jsx = False,
        emit_declaration_only = False,
        source_map = source_map,
        declaration = False,
        composite = False,
        declaration_map = False,
        emit_js = True,
        emit_dts = False,
    )

    # Run the rule producing those pre-declared outputs as well as any other outputs
    # which can not be determined ahead of time such as within directories, goruped
    # within a filegroup() etc.
    mock_impl(
        name = name,
        srcs = srcs,
        js_outs = outs.js_outs,
        map_outs = outs.map_outs,
        **kwargs
    )
