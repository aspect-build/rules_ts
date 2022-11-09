"Fixture to demonstrate a custom transpiler for ts_project"

_DUMMY_SOURCEMAP = """{"version":3,"sources":["%s"],"mappings":"AAAO,KAAK,CAAC","file":"in.js","sourcesContent":["fake"]}"""

def _mock_impl(ctx):
    src_files = [src for src in ctx.files.srcs if src.short_path.endswith(".ts") and not src.short_path.endswith(".d.ts")]
    out_files = []

    for src in src_files:
        out_path = src.short_path[len(ctx.attr.pkg_dir) + 1:] if src.short_path.startswith(ctx.attr.pkg_dir) else src.short_path

        js_file = ctx.actions.declare_file(out_path.replace(".ts", ".js"))
        map_file = ctx.actions.declare_file(out_path.replace(".ts", ".js.map"))

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

        # Used only to predeclare outputs
        "outs": attr.output_list(),

        # TODO: why is this needed?
        "pkg_dir": attr.string(),
    },
    implementation = _mock_impl,
)

def mock(name, srcs, source_map = False, **kwargs):
    # Calculate pre-declared outputs so they can be referenced as targets.
    # This is an optional transpiler feature aligning with the default tsc transpiler.
    js_outs = [
        src.replace(".ts", ".js")
        for src in srcs
        if (src.endswith(".ts") and not src.endswith(".d.ts"))
    ]
    map_outs = [js.replace(".js", ".js.map") for js in js_outs] if source_map else []

    # Run the rule producing those pre-declared outputs as well as any other outputs
    # which can not be determined ahead of time such as within directories, goruped
    # within a filegroup() etc.
    mock_impl(
        name = name,
        srcs = srcs,
        outs = js_outs + map_outs,
        pkg_dir = native.package_name(),
        **kwargs
    )
