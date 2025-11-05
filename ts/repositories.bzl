"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", _http_archive = "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//ts/private:npm_repositories.bzl", "npm_dependencies")
load("//ts/private:versions.bzl", "TOOL_VERSIONS")

LATEST_TYPESCRIPT_VERSION = TOOL_VERSIONS.keys()[-1]

def http_archive(**kwargs):
    maybe(_http_archive, **kwargs)

# WARNING: any additions to this function may be BREAKING CHANGES for users
# because we'll fetch a dependency which may be different from one that
# they were previously fetching later in their WORKSPACE setup, and now
# ours took precedence. Such breakages are challenging for users, so any
# changes in this function should be marked as BREAKING in the commit message
# and released only in semver majors.
# buildifier: disable=function-docstring
def rules_ts_bazel_dependencies():
    http_archive(
        name = "bazel_skylib",
        sha256 = "51b5105a760b353773f904d2bbc5e664d0987fbaf22265164de65d43e910d8ac",
        urls = ["https://github.com/bazelbuild/bazel-skylib/releases/download/1.8.1/bazel-skylib-1.8.1.tar.gz"],
    )

    http_archive(
        name = "aspect_rules_js",
        sha256 = "6b7e73c35b97615a09281090da3645d9f03b2a09e8caa791377ad9022c88e2e6",
        strip_prefix = "rules_js-2.0.0",
        url = "https://github.com/aspect-build/rules_js/releases/download/v2.0.0/rules_js-v2.0.0.tar.gz",
    )

    http_archive(
        name = "rules_nodejs",
        sha256 = "87c6171c5be7b69538d4695d9ded29ae2626c5ed76a9adeedce37b63c73bef67",
        strip_prefix = "rules_nodejs-6.2.0",
        url = "https://github.com/bazelbuild/rules_nodejs/releases/download/v6.2.0/rules_nodejs-v6.2.0.tar.gz",
    )

    http_archive(
        name = "aspect_tools_telemetry_report",
        sha256 = "fea3bc2f9b7896ab222756c27147b1f1b8f489df8114e03d252ffff475f8bce6",
        strip_prefix = "tools_telemetry-0.2.8",
        url = "https://github.com/aspect-build/tools_telemetry/releases/download/v0.2.8/tools_telemetry-v0.2.8.tar.gz",
    )

def rules_ts_dependencies(name = "npm_typescript", ts_version_from = None, ts_version = None, ts_integrity = None):
    """Dependencies needed by users of rules_ts.

    To skip fetching the typescript package, call `rules_ts_bazel_dependencies` instead.

    Args:
        name: name of the resulting external repository containing the TypeScript compiler.
        ts_version_from: label of a json file which declares a typescript version.

            This may be a `package.json` file, with "typescript" in the dependencies or
            devDependencies property, and the version exactly specified.

            With rules_js v1.32.0 or greater, it may also be a `resolved.json` file
            produced by `npm_translate_lock`, such as
            `@npm//path/to/linked:typescript/resolved.json`

            Exactly one of `ts_version` or `ts_version_from` must be set.
        ts_version: version of the TypeScript compiler.
            Exactly one of `ts_version` or `ts_version_from` must be set.
        ts_integrity: integrity hash for the npm package.
            By default, uses values mirrored into rules_ts.
            For example, to get the integrity of version 4.6.3 you could run
            `curl --silent https://registry.npmjs.org/typescript/4.6.3 | jq -r '.dist.integrity'`
    """

    rules_ts_bazel_dependencies()

    npm_dependencies(
        name = name,
        ts_version_from = ts_version_from,
        ts_version = ts_version,
        ts_integrity = ts_integrity,
    )
