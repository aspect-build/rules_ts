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
        sha256 = "b8a1527901774180afc798aeb28c4634bdccf19c4d98e7bdd1ce79d1fe9aaad7",
        urls = ["https://github.com/bazelbuild/bazel-skylib/releases/download/1.4.1/bazel-skylib-1.4.1.tar.gz"],
    )

    http_archive(
        name = "aspect_bazel_lib",
        sha256 = "262e3d6693cdc16dd43880785cdae13c64e6a3f63f75b1993c716295093d117f",
        strip_prefix = "bazel-lib-1.38.1",
        url = "https://github.com/aspect-build/bazel-lib/releases/download/v1.38.1/bazel-lib-v1.38.1.tar.gz",
    )

    http_archive(
        name = "aspect_rules_js",
        sha256 = "d9ceb89e97bb5ad53b278148e01a77a3e9100db272ce4ebdcd59889d26b9076e",
        strip_prefix = "rules_js-1.34.0",
        url = "https://github.com/aspect-build/rules_js/releases/download/v1.34.0/rules_js-v1.34.0.tar.gz",
    )

    http_archive(
        name = "rules_nodejs",
        sha256 = "764a3b3757bb8c3c6a02ba3344731a3d71e558220adcb0cf7e43c9bba2c37ba8",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/5.8.2/rules_nodejs-core-5.8.2.tar.gz"],
    )

def rules_ts_dependencies(ts_version_from = None, ts_version = None, ts_integrity = None, check_for_updates = True):
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
        check_for_updates: Whether to check for newer releases of rules_ts and notify the user with
            a log message when an update is available.

            Note, to better understand our users, we also include basic information about the build
            in the request to the update server. This never includes confidential or
            personally-identifying information (PII). The values sent are:

            - Currently used version. Helps us understand which older release(s) users are stuck on.
            - bzlmod (true/false). Helps us roll out this feature which is mandatory by Bazel 9.
            - Some CI-related environment variables to understand usage:
                - BUILDKITE_ORGANIZATION_SLUG
                - CIRCLE_PROJECT_USERNAME (this is *not* the username of the logged in user)
                - GITHUB_REPOSITORY_OWNER
                - BUILDKITE_BUILD_NUMBER
                - CIRCLE_BUILD_NUM
                - GITHUB_RUN_NUMBER
    """

    rules_ts_bazel_dependencies()

    npm_dependencies(
        ts_version_from = ts_version_from,
        ts_version = ts_version,
        ts_integrity = ts_integrity,
        check_for_updates = check_for_updates,
    )
