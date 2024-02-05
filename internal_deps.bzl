"""Our "development" dependencies

Users should *not* need to install these. If users see a load()
statement from these, that's a bug in our distribution.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", _http_archive = "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//.github/workflows:deps.bzl", "aspect_workflows_github_actions_deps")

def http_archive(**kwargs):
    maybe(_http_archive, **kwargs)

def rules_ts_internal_deps():
    "Fetch deps needed for local development"
    http_archive(
        name = "io_bazel_stardoc",
        sha256 = "3fd8fec4ddec3c670bd810904e2e33170bedfe12f90adf943508184be458c8bb",
        urls = ["https://github.com/bazelbuild/stardoc/releases/download/0.5.3/stardoc-0.5.3.tar.gz"],
    )

    http_archive(
        name = "aspect_rules_jasmine",
        sha256 = "5b8a9659221f2050012fb93c230ab5a5029b0b9d8aaa63ec9f1469e82a6c977e",
        strip_prefix = "rules_jasmine-0.4.0",
        url = "https://github.com/aspect-build/rules_jasmine/releases/download/v0.4.0/rules_jasmine-v0.4.0.tar.gz",
    )

    http_archive(
        name = "rules_proto",
        sha256 = "dc3fb206a2cb3441b485eb1e423165b231235a1ea9b031b4433cf7bc1fa460dd",
        strip_prefix = "rules_proto-5.3.0-21.7",
        urls = [
            "https://github.com/bazelbuild/rules_proto/archive/refs/tags/5.3.0-21.7.tar.gz",
        ],
    )

    http_archive(
        name = "buildifier_prebuilt",
        sha256 = "72b5bb0853aac597cce6482ee6c62513318e7f2c0050bc7c319d75d03d8a3875",
        strip_prefix = "buildifier-prebuilt-6.3.3",
        urls = ["https://github.com/keith/buildifier-prebuilt/archive/6.3.3.tar.gz"],
    )

    http_archive(
        name = "aspect_rules_lint",
        sha256 = "604666ec7ffd4f5f2636001ae892a0fbc29c77401bb33dd10601504e3ba6e9a7",
        strip_prefix = "rules_lint-0.6.1",
        url = "https://github.com/aspect-build/rules_lint/releases/download/v0.6.1/rules_lint-v0.6.1.tar.gz",
    )

    http_archive(
        name = "aspect_rules_swc",
        sha256 = "b647c7c31feeb7f9330fff08b45f8afe7de674d3a9c89c712b8f9d1723d0c8f9",
        strip_prefix = "rules_swc-1.0.1",
        url = "https://github.com/aspect-build/rules_swc/releases/download/v1.0.1/rules_swc-v1.0.1.tar.gz",
    )

    aspect_workflows_github_actions_deps()
