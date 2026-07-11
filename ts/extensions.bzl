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

    # rules_ts itself references @npm_typescript (e.g. the tsc used to resolve
    # tsconfig files for validation), so the default repo must exist even when
    # no module declares a deps() tag. Note that every ts_project depends on
    # @npm_typescript through the private validator attribute, so for modules
    # that never declare a deps() tag this repository is fetched at the
    # LATEST_TYPESCRIPT_VERSION default, which shifts with rules_ts releases.
    if "npm_typescript" not in selected:
        npm_dependencies(
            name = "npm_typescript",
            ts_version = LATEST_TYPESCRIPT_VERSION,
        )

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

    # rules_ts's own MODULE.bazel imports npm_typescript from a non-dev usage
    # (so @npm_typescript resolves in rules_ts .bzl files when rules_ts is a
    # dependency of another module), while its version pin is a dev tag.
    # Report the repo as a regular dependency of the root module so that the
    # non-dev use_repo() validates and `bazel mod tidy` does not move it to
    # the dev usage, which non-root modules would ignore.
    for mod in module_ctx.modules:
        if mod.is_root and mod.name == "aspect_rules_ts":
            root_direct_deps["npm_typescript"] = None

    # A repo requested by both dev and non-dev usages of the root module is a non-dev dep.
    for name in root_direct_deps.keys():
        root_direct_dev_deps.pop(name, None)

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
