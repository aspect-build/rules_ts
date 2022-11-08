"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies
"""

load("//ts/private:maybe.bzl", http_archive = "maybe_http_archive")
load("//ts/private:npm_repositories.bzl", "npm_dependencies")
load("//ts/private:versions.bzl", "TOOL_VERSIONS")

LATEST_VERSION = TOOL_VERSIONS.keys()[-1]

# WARNING: any additions to this function may be BREAKING CHANGES for users
# because we'll fetch a dependency which may be different from one that
# they were previously fetching later in their WORKSPACE setup, and now
# ours took precedence. Such breakages are challenging for users, so any
# changes in this function should be marked as BREAKING in the commit message
# and released only in semver majors.
def rules_ts_dependencies(ts_version_from = None, ts_version = None, ts_integrity = None):
    """Dependencies needed by users of rules_ts.

    To skip fetching the typescript package, define repository called `npm_typescript` before calling this.

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

    # The minimal version of bazel_skylib we require
    http_archive(
        name = "bazel_skylib",
        sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
        urls = ["https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz"],
    )

    http_archive(
        name = "rules_nodejs",
        sha256 = "50adf0b0ff6fc77d6909a790df02eefbbb3bc2b154ece3406361dda49607a7bd",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/5.7.1/rules_nodejs-core-5.7.1.tar.gz"],
    )

    http_archive(
        name = "aspect_rules_js",
        sha256 = "99657daed85eb5e764663fc2a534d4488b3b157719d9ddc64fbac0fd4510b677",
        strip_prefix = "rules_js-1.6.8",
        url = "https://github.com/aspect-build/rules_js/archive/refs/tags/v1.6.8.tar.gz",
    )

    http_archive(
        name = "aspect_bazel_lib",
        sha256 = "3534a27621725fbbf1d3e53daa0c1dda055a2732d9031b8c579f917d7347b6c4",
        strip_prefix = "bazel-lib-1.16.1",
        url = "https://github.com/aspect-build/bazel-lib/archive/refs/tags/v1.16.1.tar.gz",
    )

    npm_dependencies(ts_version_from = ts_version_from, ts_version = ts_version, ts_integrity = ts_integrity)
