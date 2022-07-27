load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

ts_project(
    name = "feature4",
    srcs = ["index.ts"],
    declaration = True,
    tsconfig = {},
    visibility = ["//visibility:public"],
    deps = [
        ":logic1",
        ":logic2",
        "//feature4/src/logic3",
    ],
)

ts_project(
    name = "logic1",
    srcs = ["src/logic1.ts"],
    declaration = True,
    tsconfig = {},
    deps = ["//feature4/helper"],
)

ts_project(
    name = "logic2",
    srcs = ["src/logic2.ts"],
    declaration = True,
    tsconfig = {},
    deps = ["//feature4/helper"],
)
