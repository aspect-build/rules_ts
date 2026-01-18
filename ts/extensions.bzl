"""Define module extensions for using rules_ts with bzlmod.
See https://bazel.build/docs/bzlmod#extension-definition
"""

load("//ts:repositories.bzl", "LATEST_TYPESCRIPT_VERSION")
load("//ts/private:npm_repositories.bzl", "npm_dependencies")

def _extension_impl(module_ctx):
    # Prefer the root module's tag when multiple modules request the same repo.
    selected = {}
    for mod in module_ctx.modules:
        is_root = hasattr(mod, "is_root") and mod.is_root
        for attr in mod.tags.deps:
            existing = selected.get(attr.name)
            if existing and not is_root:
                continue
            selected[attr.name] = {
                "attr": attr,
                "is_root": is_root,
            }

    for entry in selected.values():
        attr = entry["attr"]
        if attr.ts_version_from and hasattr(module_ctx, "watch"):
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
