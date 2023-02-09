load("@bazel_skylib//rules:build_test.bzl", "build_test")

# `ts_project()` should be able to build from the non-main workspace.
build_test(
    name = "test",
    targets = ["@lib_wksp//:lib"],
)
