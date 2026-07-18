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
    name = "lib.ts7rc",
    srcs = ["lib.ts"],
    composite = True,
    out_dir = "ts7rc_out",
    tsc = "@npm_typescript-7rc//:tsc",
    validator = "@npm_typescript-7rc//:validator",
)

# Validation must accept an option implied as a computed default of another
# (checkJs implies allowJs) without the implied attribute being set. See the
# composite -> declaration/incremental cases on ':lib' and ':lib.ts7rc'.
ts_project(
    name = "implied_checkjs",
    srcs = ["lib.ts"],
    out_dir = "implied_checkjs_out",
    tsconfig = "tsconfig-checkjs.json",
)

ts_project(
    name = "implied_checkjs.ts7rc",
    srcs = ["lib.ts"],
    out_dir = "implied_checkjs_ts7rc_out",
    tsc = "@npm_typescript-7rc//:tsc",
    tsconfig = "tsconfig-checkjs.json",
    validator = "@npm_typescript-7rc//:validator",
)

# TypeScript 5.9 resolves `module: nodenext` to also imply resolveJsonModule;
# the validator must accept resolve_json_module unset.
ts_project(
    name = "implied_resolve_json_module",
    srcs = ["lib.ts"],
    out_dir = "implied_resolve_json_module_out",
    tsc = "@npm_typescript-59//:tsc",
    tsconfig = "tsconfig-nodenext.json",
    validator = "@npm_typescript-59//:validator",
)

build_test(
    name = "test",
    targets = [
        ":lib",
        "lib.ts5",
        "lib.ts56rc",
        "lib.ts7rc",
        "implied_checkjs",
        "implied_checkjs.ts7rc",
        "implied_resolve_json_module",
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
