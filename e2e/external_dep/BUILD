"""Tests a `ts_project()` in one workspace being used in another."""

load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

ts_project(
    name = "lib",
    srcs = ["lib.ts"],
    # Composite to also check the location of .tsbuildinfo
    # https://github.com/aspect-build/rules_ts/issues/329
    composite = True,
    visibility = ["//visibility:public"],
)

build_test(
    name = "test",
    targets = [":lib"],
)
