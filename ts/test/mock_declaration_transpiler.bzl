"Fixture to demonstrate a custom declaration transpiler for ts_project"

load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("@aspect_rules_ts//ts/private:ts_lib.bzl", "lib")

def _mock_impl(ctx):
    out_files = []

    for src in ctx.files.srcs:
        out_path = src.short_path

        if out_path.endswith(".json"):
            continue

        dts_file = ctx.actions.declare_file(lib.relative_to_package(out_path.replace(".ts", ".d.ts"), ctx))
        out_files.append(dts_file)

        ctx.actions.run_shell(
            inputs = [src],
            outputs = [dts_file],
            command = "cp $@",
            arguments = [src.path, dts_file.path],
        )

    output_types_depset = depset(out_files)

    return [
        JsInfo(
            target = ctx.label,
            sources = depset(),
            types = output_types_depset,
            transitive_sources = depset(),
            transitive_types = depset(),
            npm_sources = depset(),
            npm_package_store_infos = depset(),
        ),
        DefaultInfo(
            files = output_types_depset,
        ),
    ]

mock_impl = rule(
    attrs = {
        "srcs": attr.label_list(
            doc = "TypeScript source files",
            allow_files = True,
            mandatory = True,
        ),
    },
    implementation = _mock_impl,
)

def mock(name, srcs, **kwargs):
    # Run the rule producing those pre-declared outputs as well as any other outputs
    # which can not be determined ahead of time such as within directories, grouped
    # within a filegroup() etc.
    mock_impl(
        name = name,
        srcs = srcs,
        **kwargs
    )
