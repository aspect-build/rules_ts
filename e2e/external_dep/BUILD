"""Tests a `ts_project()` in one workspace being used in another."""

load("@aspect_rules_js//js:defs.bzl", "js_test")
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
# Picks up TypeScript 5.0.4 defined in MODULE.bazel
ts_project(
    name = "lib.ts5",
    srcs = ["lib.ts"],
    composite = True,
    out_dir = "ts5_out",
    tsc = "@npm_typescript5//:tsc",
)

ts_project(
    name = "lib.ts56rc",
    srcs = ["lib.ts"],
    composite = True,
    out_dir = "ts56rc_out",
    tsc = "@npm_typescript-56rc//:tsc",
)

ts_project(
    name = "lib.ts7",
    srcs = ["lib.ts"],
    composite = True,
    out_dir = "ts7_out",
    tsc = "@npm_typescript-7//:tsc",
    validator = "@npm_typescript-7//:validator",
)

js_test(
    name = "validator_version_test",
    args = ["$(rootpath @npm_typescript-7_validator//:node_modules/typescript/dir)"],
    data = ["@npm_typescript-7_validator//:node_modules/typescript/dir"],
    entry_point = "validator_version_test.cjs",
)

build_test(
    name = "test",
    targets = [
        ":lib",
        "lib.ts5",
        "lib.ts56rc",
        "lib.ts7",
        "validator_version_test",
    ],
)

ts_project(
    name = "external-deps",
    srcs = ["lib.ts"],
    composite = True,
    out_dir = "external-deps",
    visibility = ["//visibility:public"],
    deps = [
        "@sub_external//:lib-with-asset",
        "@sub_external//:lib1",
        "@sub_external//:tsconfig-dict",
        "@sub_external//subdir:lib-with-asset",
        "@sub_external//subdir:lib1",
        "@sub_external//subdir:tsconfig-dict",
    ],
)

build_test(
    name = "test-external",
    targets = [
        ":external-deps",
        "@sub_external//:lib1",
        "@sub_external//:lib-with-asset",
        "@sub_external//:tsconfig-dict",
        "@sub_external//subdir:lib1",
        "@sub_external//subdir:lib-with-asset",
        "@sub_external//subdir:tsconfig-dict",
    ],
)
