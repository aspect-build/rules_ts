"""Aspect Workflows bazel dependencies"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

ASPECT_WORKFLOWS_VERSION = "5.9.0-beta.10"
ASPECT_WORKFLOWS_ACTION_SHA256 = "14ad210115f03a1f002ade3d54f0a4813ecc0cbfd79e9bcd6233f575a1bfd2ec"

def aspect_workflows_github_actions_deps():
    "Fetch deps needed for Aspect Workflows on GitHub Actions"
    http_archive(
        name = "aspect_workflows_action",
        sha256 = ASPECT_WORKFLOWS_ACTION_SHA256,
        strip_prefix = "workflows-action-{}".format(ASPECT_WORKFLOWS_VERSION),
        url = "https://github.com/aspect-build/workflows-action/archive/refs/tags/{}.tar.gz".format(ASPECT_WORKFLOWS_VERSION),
        build_file_content = """exports_files(glob([".github/workflows/.aspect-workflows-reusable.yaml"]))""",
    )
