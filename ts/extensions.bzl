"""Define module extensions for using rules_ts with bzlmod.
See https://bazel.build/docs/bzlmod#extension-definition
"""

load("//ts/private:npm_repositories.bzl", "npm_dependencies")
load("//ts/private:versions.bzl", "TOOL_VERSIONS")

LATEST_TYPESCRIPT_VERSION = TOOL_VERSIONS.keys()[-1]

def _extension_impl(module_ctx):
    # Prefer the root module's tag when multiple modules request the same repo.
    selected = {}
    root_direct_deps = {}
    root_direct_dev_deps = {}
    for mod in module_ctx.modules:
        is_root = mod.is_root
        for attr in mod.tags.toolchain:
            if is_root:
                if module_ctx.is_dev_dependency(attr):
                    root_direct_dev_deps[attr.name] = None
                else:
                    root_direct_deps[attr.name] = None
            existing = selected.get(attr.name)
            if existing and not is_root:
                # Validate that non-root modules don't specify conflicting versions
                if not existing["is_root"]:
                    existing_attr = existing["attr"]
                    if attr.version != existing_attr.version or \
                       attr.version_from != existing_attr.version_from or \
                       attr.integrity != existing_attr.integrity:
                        fail("""Multiple non-root modules specify different versions for '{name}'.
    Module '{existing_mod}' requests: version={existing_version}, version_from={existing_from}, integrity={existing_integrity}
    Module '{current_mod}' requests: version={current_version}, version_from={current_from}, integrity={current_integrity}
To resolve this conflict, the root module should explicitly specify the desired version.""".format(
                            name = attr.name,
                            existing_mod = existing["module_name"],
                            existing_version = existing_attr.version or "(not set)",
                            existing_from = existing_attr.version_from or "(not set)",
                            existing_integrity = existing_attr.integrity or "(not set)",
                            current_mod = mod.name,
                            current_version = attr.version or "(not set)",
                            current_from = attr.version_from or "(not set)",
                            current_integrity = attr.integrity or "(not set)",
                        ))
                continue
            selected[attr.name] = {
                "attr": attr,
                "is_root": is_root,
                "module_name": mod.name,
            }

    for entry in selected.values():
        attr = entry["attr"]
        if attr.version_from:
            module_ctx.watch(attr.version_from)

        ts_version = attr.version
        if not ts_version and not attr.version_from:
            ts_version = LATEST_TYPESCRIPT_VERSION
        npm_dependencies(
            name = attr.name,
            ts_version = ts_version,
            ts_version_from = attr.version_from,
            ts_integrity = attr.integrity,
        )

    # A repo requested by both dev and non-dev usages of the root module is a non-dev dep.
    for name in root_direct_deps.keys():
        root_direct_dev_deps.pop(name, None)

    return module_ctx.extension_metadata(
        root_module_direct_deps = root_direct_deps.keys(),
        root_module_direct_dev_deps = root_direct_dev_deps.keys(),
        # Reproducible: every fetch is pinned by integrity or the integrity mirrored in ts/private/versions.bzl.
        reproducible = True,
    )

typescript = module_extension(
    implementation = _extension_impl,
    tag_classes = {
        "toolchain": tag_class(attrs = {
            "name": attr.string(default = "npm_typescript"),
            "version": attr.string(),
            "version_from": attr.label(),
            "integrity": attr.string(),
        }),
    },
)
