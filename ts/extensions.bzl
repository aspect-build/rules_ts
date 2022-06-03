load("//ts/private:npm_typescript_repository.bzl", "npm_typescript_repository")

def _extension_impl(module_ctx):
    for mod in module_ctx.modules:
        for attr in mod.tags.npm_typescript:
            npm_typescript_repository(ts_version = attr.ts_version, ts_version_from = attr.ts_version_from, ts_integrity = attr.ts_integrity)

ext = module_extension(
    implementation = _extension_impl,
    tag_classes = {
        "npm_typescript": tag_class(attrs = dict({"name": attr.string(mandatory = True), "ts_version": attr.string(), "ts_version_from": attr.label(), "ts_integrity": attr.string()}))
    },
)
