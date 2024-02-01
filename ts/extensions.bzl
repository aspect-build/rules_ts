"""Define module extensions for using rules_ts with bzlmod.
See https://bazel.build/docs/bzlmod#extension-definition
"""

load("//ts:repositories.bzl", "LATEST_TYPESCRIPT_VERSION")
load("//ts/private:npm_repositories.bzl", "npm_dependencies")

def _extension_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.deps:
            ts_version = attr.ts_version
            if not ts_version and not attr.ts_version_from:
                ts_version = LATEST_TYPESCRIPT_VERSION
            npm_dependencies(
                ts_version = ts_version,
                ts_version_from = attr.ts_version_from,
                ts_integrity = attr.ts_integrity,
                bzlmod = True,
            )

ext = module_extension(
    implementation = _extension_impl,
    tag_classes = {
        "deps": tag_class(attrs = {
            "ts_version": attr.string(),
            "ts_version_from": attr.label(),
            "ts_integrity": attr.string(),
        }),
    },
)
