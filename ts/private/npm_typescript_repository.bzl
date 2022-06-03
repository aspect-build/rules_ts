"Repository rule for fetching typescript"

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//ts/private:versions.bzl", TS_VERSIONS = "VERSIONS")

def _http_archive_version_impl(rctx):
    if rctx.attr.version:
        version = rctx.attr.version
    else:
        json_path = rctx.path(rctx.attr.version_from)
        p = json.decode(rctx.read(json_path))
        if "devDependencies" in p.keys() and "typescript" in p["devDependencies"]:
            ts = p["devDependencies"]["typescript"]
        elif "dependencies" in p.keys() and "typescript" in p["dependencies"]:
            ts = p["dependencies"]["typescript"]
        else:
            fail("key `typescript` not found in either dependencies or devDependencies of %s" % json_path)
        if any([not seg.isdigit() for seg in ts.split(".")]):
            fail("""typescript version in package.json must be exactly specified, not a semver range: %s.
            You can supply an exact `ts_version` attribute to `rules_ts_dependencies` to bypass this check.""" % ts)
        version = ts

    if rctx.attr.integrity:
        integrity = rctx.attr.integrity
    elif version in TS_VERSIONS.keys():
        integrity = TS_VERSIONS[version]
    else:
        fail("""typescript version {} is not mirrored in rules_ts, is this a real version?
            If so, you must manually set `ts_integrity`.
            See documentation on rules_ts_dependencies.""".format(version))

    rctx.download_and_extract(
        url = [u.format(version) for u in rctx.attr.urls],
        integrity = integrity,
    )
    rctx.symlink(rctx.path(rctx.attr.build_file), "BUILD.bazel")

http_archive_version = repository_rule(
    doc = "Re-implementation of http_archive that can read the version from package.json",
    implementation = _http_archive_version_impl,
    attrs = {
        "integrity": attr.string(doc = "Needed only if the ts version isn't mirrored in `versions.bzl`."),
        "version": attr.string(doc = "Explicit version for `urls` placeholder. If provided, the package.json is not read."),
        "urls": attr.string_list(doc = "URLs to fetch from. Each must have one `{}`-style placeholder."),
        "build_file": attr.label(doc = "The BUILD file to symlink into the created repository."),
        "version_from": attr.label(doc = "Location of package.json which may have a version for the package."),
    },
)

def npm_typescript_repository(ts_version_from = None, ts_version = None, ts_integrity = None):
    maybe(
        http_archive_version,
        name = "npm_typescript",
        version = ts_version,
        version_from = ts_version_from,
        integrity = ts_integrity,
        build_file = "@aspect_rules_ts//ts:BUILD.typescript",
        urls = ["https://registry.npmjs.org/typescript/-/typescript-{}.tgz"],
    )
