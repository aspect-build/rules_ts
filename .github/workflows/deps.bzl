"""Aspect Workflows bazel dependencies"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

ASPECT_WORKFLOWS_VERSION = "5.10.12"
ASPECT_WORKFLOWS_ACTION_INTEGRITY = "sha256-LOm+hsAJ6H7vBo6yythu6Cwoy7y0oNvXBGTd/Iggx7I="

def aspect_workflows_github_actions_deps():
    "Fetch deps needed for Aspect Workflows on GitHub Actions"
    http_archive(
        name = "aspect_workflows_action",
        integrity = ASPECT_WORKFLOWS_ACTION_INTEGRITY,
        strip_prefix = "workflows-action-{}".format(ASPECT_WORKFLOWS_VERSION),
        url = "https://github.com/aspect-build/workflows-action/archive/refs/tags/{}.tar.gz".format(ASPECT_WORKFLOWS_VERSION),
        build_file_content = """exports_files(glob([".github/workflows/.aspect-workflows-reusable.yaml"]))""",
    )
