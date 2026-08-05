load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

# Emit + type-check in a single action.
ts_project(
    name = "lib",
    srcs = [
        "lib.ts",
        "main.ts",
    ],
    declaration = True,
    out_dir = "out",
    transpiler = "tsc",
)

# Emit and type-check in separate actions; the type-check action
# exercises the .typecheck marker output.
ts_project(
    name = "lib_isolated",
    srcs = [
        "lib.ts",
        "main.ts",
    ],
    declaration = True,
    extends = "tsconfig.json",
    isolated_typecheck = True,
    out_dir = "isolated",
    transpiler = "tsc",
    tsconfig = "tsconfig-isolated.json",
)

# A second native TypeScript version used by this target only, selected via an
# explicit toolchain instead of the globally registered one.
ts_project(
    name = "lib_ts7rc",
    srcs = [
        "lib.ts",
        "main.ts",
    ],
    declaration = True,
    out_dir = "ts7rc",
    transpiler = "tsc",
    tsc_toolchain = "@npm_typescript_7rc//:tsc_toolchain",
)

build_test(
    name = "test",
    targets = [
        ":lib",
        ":lib_isolated",
        ":lib_ts7rc",
    ],
)
