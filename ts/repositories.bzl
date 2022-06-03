"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//ts/private:npm_typescript_repository.bzl", "npm_typescript_repository", _http_archive_version = "http_archive_version")
load("//ts/private:versions.bzl", _LATEST_VERSION = "LATEST_VERSION", _TS_VERSIONS = "VERSIONS")

TS_VERSIONS = _TS_VERSIONS
LATEST_VERSION = _LATEST_VERSION

http_archive_version = _http_archive_version

versions = struct(
    bazel_lib = "0.12.1",
    rules_nodejs = "5.4.0",
    rules_js = "0.9.1",
)

# WARNING: any additions to this function may be BREAKING CHANGES for users
# because we'll fetch a dependency which may be different from one that
# they were previously fetching later in their WORKSPACE setup, and now
# ours took precedence. Such breakages are challenging for users, so any
# changes in this function should be marked as BREAKING in the commit message
# and released only in semver majors.
def rules_ts_dependencies(ts_version_from = None, ts_version = None, ts_integrity = None):
    """Dependencies needed by users of rules_ts.

    To skip fetching the typescript package, define repository called 'npm_typescript' before calling this.

    Args:
        ts_version_from: label of a json file (typically `package.json`) which declares an exact typescript version
            in a dependencies or devDependencies property.
            Exactly one of `ts_version` or `ts_version_from` must be set.
        ts_version: version of the TypeScript compiler.
            Exactly one of `ts_version` or `ts_version_from` must be set.
        ts_integrity: integrity hash for the npm package.
            By default, uses values mirrored into rules_ts.
            For example, to get the integrity of version 4.6.3 you could run
            `curl --silent https://registry.npmjs.org/typescript/4.6.3 | jq -r '.dist.integrity'`
    """

    if (ts_version and ts_version_from) or (not ts_version_from and not ts_version):
        fail("""Exactly one of `ts_version` or `ts_version_from` must be set.""")

    # The minimal version of bazel_skylib we require
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "c6966ec828da198c5d9adbaa94c05e3a1c7f21bd012a0b29ba8ddbccb2c93b0d",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.1.1/bazel-skylib-1.1.1.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "rules_nodejs",
        sha256 = "1f9fca05f4643d15323c2dee12bd5581351873d45457f679f84d0fe0da6839b7",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/{0}/rules_nodejs-core-{0}.tar.gz".format(versions.rules_nodejs)],
    )

    maybe(
        http_archive,
        name = "aspect_rules_js",
        sha256 = "f4693a937c5852e660d1da773436fc3dc3a6274b25f735c233a8cffc12ed2dbb",
        strip_prefix = "rules_js-0.11.0",
        url = "https://github.com/aspect-build/rules_js/archive/refs/tags/v0.11.0.tar.gz",
    )

    maybe(
        http_archive,
        name = "aspect_bazel_lib",
        sha256 = "91aa7356b22ecdb87dcf5f1cc8a6a147e23a1ef425221bab75e5f857cd6b2716",
        strip_prefix = "bazel-lib-" + versions.bazel_lib,
        url = "https://github.com/aspect-build/bazel-lib/archive/refs/tags/v{}.tar.gz".format(versions.bazel_lib),
    )

    npm_typescript_repository(ts_version_from = ts_version_from, ts_version = ts_version, ts_integrity = ts_integrity)
