"""Runtime dependencies fetched from npm"""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//ts/private:versions.bzl", "TOOL_VERSIONS")

def _http_archive_version_impl(rctx):
    integrity = None
    if rctx.attr.version:
        version = rctx.attr.version
    else:
        json_path = rctx.path(rctx.attr.version_from)
        p = json.decode(rctx.read(json_path))

        # Allow use of "resolved.json", see https://github.com/aspect-build/rules_js/pull/1221
        if "$schema" in p.keys() and p["$schema"] == "https://docs.aspect.build/rules/aspect_rules_js/docs/npm_translate_lock":
            ts = p["version"]
            integrity = p["integrity"]
        elif "devDependencies" in p.keys() and "typescript" in p["devDependencies"]:
            ts = p["devDependencies"]["typescript"]
        elif "dependencies" in p.keys() and "typescript" in p["dependencies"]:
            ts = p["dependencies"]["typescript"]
        else:
            fail("key 'typescript' not found in either dependencies or devDependencies of %s" % json_path)
        version = ts

    if integrity:
        pass
    elif rctx.attr.integrity:
        integrity = rctx.attr.integrity
    elif version in TOOL_VERSIONS.keys():
        integrity = TOOL_VERSIONS[version]
    else:
        fail("""typescript version {} is not mirrored in rules_ts, is this a real version?
            If so, you must manually set 'ts_integrity'.
            If this is a semver range you must specify an exact version instead.
            See documentation on rules_ts_dependencies.""".format(version))

    urls = [u.format(version) for u in rctx.attr.urls]

    rctx.download_and_extract(
        url = urls,
        integrity = integrity,
        # Prevents accidental re-use of cached versions that would otherwise
        # be used purely based on the "integrity" value. E.g. someone forgot
        # to update the integrity but the `ts_version` is already different.
        canonical_id = get_default_canonical_id(rctx, urls),
    )
    build_file_substitutions = {
        "ts_version": version,
        # Note: we can't depend on bazel_skylib because this code is called from
        # rules_ts_dependencies so it's not "in scope" yet.
        # So we can't use versions.bzl to parse the version
        "is_ts_5": str(int(version.split(".")[0]) >= 5),
    }
    rctx.template(
        "BUILD.bazel",
        rctx.path(rctx.attr._build_file),
        substitutions = build_file_substitutions,
        executable = False,
    )

http_archive_version = repository_rule(
    doc = "Re-implementation of http_archive that can read the version from package.json",
    implementation = _http_archive_version_impl,
    attrs = {
        "integrity": attr.string(doc = "Needed only if the ts version isn't mirrored in `versions.bzl`."),
        "version": attr.string(doc = "Explicit version for `urls` placeholder. If provided, the package.json is not read."),
        "urls": attr.string_list(doc = "URLs to fetch from. Each must have one `{}`-style placeholder."),
        "_build_file": attr.label(
            doc = "The BUILD file to write into the created repository.",
            default = Label("@aspect_rules_ts//ts:BUILD.typescript"),
        ),
        "version_from": attr.label(doc = "Location of package.json which may have a version for the package."),
    },
)

# buildifier: disable=function-docstring
def npm_dependencies(name = "npm_typescript", ts_version_from = None, ts_version = None, ts_integrity = None):
    if (ts_version and ts_version_from) or (not ts_version_from and not ts_version):
        fail("""Exactly one of 'ts_version' or 'ts_version_from' must be set.""")

    maybe(
        http_archive_version,
        name = name,
        version = ts_version,
        version_from = ts_version_from,
        integrity = ts_integrity,
        urls = ["https://registry.npmjs.org/typescript/-/typescript-{}.tgz"],
    )

# Copy of Bazel's new helper that is not available in Bazel 6
# https://github.com/bazelbuild/bazel/blob/7a29e3885da88c2b2dd9a07a622b62d7ea81f8a1/tools/build_defs/repo/cache.bzl#L39
def get_default_canonical_id(rctx, urls):
    if rctx.os.environ.get("BAZEL_HTTP_RULES_URLS_AS_DEFAULT_CANONICAL_ID") == "0":
        return ""
    return " ".join(urls)
