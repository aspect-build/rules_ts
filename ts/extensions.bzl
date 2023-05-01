"""Define module extensions for using rules_ts with bzlmod.
See https://bazel.build/docs/bzlmod#extension-definition
"""

load("//ts/private:npm_repositories.bzl", "npm_dependencies")
load("//ts:repositories.bzl", "LATEST_TYPESCRIPT_VERSION")

def _extension_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.deps:
            npm_dependencies(ts_version = attr.ts_version, ts_integrity = attr.ts_integrity)

ext = module_extension(
    implementation = _extension_impl,
    tag_classes = {
        "deps": tag_class(attrs = {"ts_version": attr.string(default = LATEST_TYPESCRIPT_VERSION), "ts_integrity": attr.string()}),
    },
)
