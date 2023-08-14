load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

ts_project(
    name = "ts",
    srcs = ["foo.ts"],
    extends = "tsconfig.json",
    transpiler = "tsc",
    tsconfig = {
        "extends": "tsconfig.json",
    },
)

build_test(
    name = "test",
    targets = [":ts"],
)
