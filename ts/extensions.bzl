"""Define module extensions for using rules_ts with bzlmod.
See https://bazel.build/docs/bzlmod#extension-definition
"""

load("//ts/private:npm_repositories.bzl", "npm_dependencies")
load("//ts/private:tsc_repositories.bzl", "tsc_toolchain_repositories", "tsc_toolchains_repo")
load("//ts/private:versions.bzl", "TOOL_VERSIONS")

LATEST_TYPESCRIPT_VERSION = TOOL_VERSIONS.keys()[-1]

_DEFAULT_REPOSITORY = "npm_typescript"

def _extension_impl(module_ctx):
    # Prefer the root module's tag when multiple modules request the same repo.
    selected = {}
    root_direct_deps = {}
    root_direct_dev_deps = {}
    for mod in module_ctx.modules:
        is_root = mod.is_root
        for attr in mod.tags.deps:
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
                    if attr.ts_version != existing_attr.ts_version or \
                       attr.ts_version_from != existing_attr.ts_version_from or \
                       attr.ts_integrity != existing_attr.ts_integrity:
                        fail("""Multiple non-root modules specify different versions for '{name}'.
    Module '{existing_mod}' requests: ts_version={existing_version}, ts_version_from={existing_from}, ts_integrity={existing_integrity}
    Module '{current_mod}' requests: ts_version={current_version}, ts_version_from={current_from}, ts_integrity={current_integrity}
To resolve this conflict, the root module should explicitly specify the desired version.""".format(
                            name = attr.name,
                            existing_mod = existing["module_name"],
                            existing_version = existing_attr.ts_version or "(not set)",
                            existing_from = existing_attr.ts_version_from or "(not set)",
                            existing_integrity = existing_attr.ts_integrity or "(not set)",
                            current_mod = mod.name,
                            current_version = attr.ts_version or "(not set)",
                            current_from = attr.ts_version_from or "(not set)",
                            current_integrity = attr.ts_integrity or "(not set)",
                        ))
                continue
            selected[attr.name] = {
                "attr": attr,
                "is_root": is_root,
                "module_name": mod.name,
            }

    for entry in selected.values():
        attr = entry["attr"]
        if attr.ts_version_from:
            module_ctx.watch(attr.ts_version_from)

        ts_version = attr.ts_version
        if not ts_version and not attr.ts_version_from:
            ts_version = LATEST_TYPESCRIPT_VERSION
        npm_dependencies(
            name = attr.name,
            ts_version = ts_version,
            ts_version_from = attr.ts_version_from,
            ts_integrity = attr.ts_integrity,
        )

        # The compiler is provided to ts_project via toolchain resolution:
        # native TypeScript versions (7+) are invoked directly from pre-compiled
        # binaries, while other versions use the NodeJS-hosted compiler.
        # rules_ts registers "@npm_typescript_toolchains//:all" in its MODULE.bazel;
        # toolchains for other repository names can either be registered by the root
        # module or selected per-target via ts_project(tsc_toolchain).
        tsc_toolchain_repositories(
            name = attr.name,
            ts_version = ts_version,
            ts_version_from = attr.ts_version_from,
        )

    # rules_ts unconditionally registers "@npm_typescript_toolchains//:all", so that
    # repository must exist (empty) even when no module requests the default repository.
    if _DEFAULT_REPOSITORY not in selected:
        tsc_toolchains_repo(
            name = _DEFAULT_REPOSITORY + "_toolchains",
            user_repository_name = _DEFAULT_REPOSITORY,
        )

    # A repo requested by both dev and non-dev usages of the root module is a non-dev dep.
    for name in root_direct_deps.keys():
        root_direct_dev_deps.pop(name, None)

    # rules_ts's own MODULE.bazel imports the default toolchains hub (non-dev) in
    # order to register_toolchains() it on behalf of all consumers.
    if module_ctx.modules and module_ctx.modules[0].is_root and module_ctx.modules[0].name == "aspect_rules_ts":
        root_direct_deps[_DEFAULT_REPOSITORY + "_toolchains"] = None
        root_direct_dev_deps.pop(_DEFAULT_REPOSITORY + "_toolchains", None)

    return module_ctx.extension_metadata(
        root_module_direct_deps = root_direct_deps.keys(),
        root_module_direct_dev_deps = root_direct_dev_deps.keys(),
        # Reproducible: every fetch is pinned by ts_integrity or the integrity mirrored in ts/private/versions.bzl.
        reproducible = True,
    )

ext = module_extension(
    implementation = _extension_impl,
    tag_classes = {
        "deps": tag_class(attrs = {
            "name": attr.string(default = "npm_typescript"),
            "ts_version": attr.string(),
            "ts_version_from": attr.label(),
            "ts_integrity": attr.string(),
        }),
    },
)
