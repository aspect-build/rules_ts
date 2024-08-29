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

# Demonstrate how to use a different typescript where required
# Picks up TypeScript 3.9.9 defined in MODULE.bazel
ts_project(
    name = "lib.ts3",
    srcs = ["lib.ts"],
    composite = True,
    out_dir = "ts3_out",
    tsc = "@npm_typescript3//:tsc",
)

ts_project(
    name = "lib.ts56rc",
    srcs = ["lib.ts"],
    composite = True,
    out_dir = "ts56rc_out",
    tsc = "@npm_typescript-56rc//:tsc",
)

build_test(
    name = "test",
    targets = [
        ":lib",
        "lib.ts3",
        "lib.ts56rc",
    ],
)
