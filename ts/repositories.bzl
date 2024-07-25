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
        sha256 = "cd55a062e763b9349921f0f5db8c3933288dc8ba4f76dd9416aac68acee3cb94",
        urls = ["https://github.com/bazelbuild/bazel-skylib/releases/download/1.5.0/bazel-skylib-1.5.0.tar.gz"],
    )

    http_archive(
        name = "aspect_bazel_lib",
        sha256 = "6d758a8f646ecee7a3e294fbe4386daafbe0e5966723009c290d493f227c390b",
        strip_prefix = "bazel-lib-2.7.7",
        url = "https://github.com/aspect-build/bazel-lib/releases/download/v2.7.7/bazel-lib-v2.7.7.tar.gz",
    )

    http_archive(
        name = "aspect_rules_js",
        sha256 = "c1c33715f459d112b53b2bb15fd53a738824c6d331a181abe33fe0ef2a2c3f1f",
        strip_prefix = "rules_js-2.0.0-rc8",
        url = "https://github.com/aspect-build/rules_js/releases/download/v2.0.0-rc8/rules_js-v2.0.0-rc8.tar.gz",
    )

    http_archive(
        name = "rules_nodejs",
        sha256 = "87c6171c5be7b69538d4695d9ded29ae2626c5ed76a9adeedce37b63c73bef67",
        strip_prefix = "rules_nodejs-6.2.0",
        url = "https://github.com/bazelbuild/rules_nodejs/releases/download/v6.2.0/rules_nodejs-v6.2.0.tar.gz",
    )

def rules_ts_dependencies(ts_version_from = None, ts_version = None, ts_integrity = None):
    """Dependencies needed by users of rules_ts.

    To skip fetching the typescript package, call `rules_ts_bazel_dependencies` instead.

    Args:
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
        ts_version_from = ts_version_from,
        ts_version = ts_version,
        ts_integrity = ts_integrity,
    )
