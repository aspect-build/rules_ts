"""Expose some files with DeclarationInfo, like fileset but can be a dep of ts_project

Internal-only for now.
"""

load("@rules_nodejs//nodejs:providers.bzl", "DeclarationInfo", "declaration_info")

def _ts_declaration_impl(ctx):
    all_files = []
    typings = []

    for src in ctx.files.srcs:
        all_files.append(src)
        if src.is_directory:
            # assume a directory contains typings since we can't know that it doesn't
            typings.append(src)
        elif (
            src.path.endswith(".d.ts") or
            src.path.endswith(".d.ts.map") or
            # package.json may be required to resolve "typings" key
            src.path.endswith("/package.json")
        ):
            typings.append(src)

    typings_depsets = [depset(typings)]
    files_depsets = [depset(all_files)]

    for dep in ctx.attr.deps:
        if DeclarationInfo in dep:
            typings_depsets.append(dep[DeclarationInfo].declarations)
        if DefaultInfo in dep:
            files_depsets.append(dep[DefaultInfo].files)

    runfiles = ctx.runfiles(
        files = all_files,
        # We do not include typings_depsets in the runfiles because that would cause type-check actions to occur
        # in every development workflow.
        transitive_files = depset(transitive = files_depsets),
    )
    deps_runfiles = [d[DefaultInfo].default_runfiles for d in ctx.attr.deps]
    decls = depset(transitive = typings_depsets)

    return [
        DefaultInfo(
            files = depset(transitive = files_depsets),
            runfiles = runfiles.merge_all(deps_runfiles),
        ),
        declaration_info(
            declarations = decls,
            deps = ctx.attr.deps,
        ),
        OutputGroupInfo(types = decls),
    ]

ts_declaration = rule(
    implementation = _ts_declaration_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(allow_files = True),
    },
    provides = [DeclarationInfo],
)
