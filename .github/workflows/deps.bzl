"""Aspect Workflows bazel dependencies"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

ASPECT_WORKFLOWS_VERSION = "5.8.0-rc8"
ASPECT_WORKFLOWS_ACTION_SHA256 = "e53cc20d417b18c1b8a1deb323962e7d0306b28d8f7e23d93612110301d3c0bd"

def aspect_workflows_github_actions_deps():
    "Fetch deps needed for Aspect Workflows on GitHub Actions"
    http_archive(
        name = "aspect_workflows_action",
        sha256 = ASPECT_WORKFLOWS_ACTION_SHA256,
        strip_prefix = "workflows-action-{}".format(ASPECT_WORKFLOWS_VERSION),
        url = "https://github.com/aspect-build/workflows-action/archive/refs/tags/{}.tar.gz".format(ASPECT_WORKFLOWS_VERSION),
        build_file_content = """exports_files(glob([".github/workflows/.aspect-workflows-reusable.yaml"]))""",
    )
