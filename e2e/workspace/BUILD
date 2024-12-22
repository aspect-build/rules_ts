load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

ts_project(
    name = "ts",
    srcs = ["foo.ts"],
)

ts_project(
    name = "ts-out-dir",
    srcs = ["foo.ts"],
    out_dir = "out",
)

build_test(
    name = "test",
    targets = [":ts"],
)
