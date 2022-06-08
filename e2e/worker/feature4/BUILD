load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

ts_project(
    name = "feature4",
    srcs = ["index.ts"],
    deps = [
        ":logic1",
        ":logic2",
        "//feature4/src/logic3"
    ],
    declaration = True,
    visibility = ["//visibility:public"],
    tsconfig = {},
)


ts_project(
    name = "logic1",
    srcs = ["src/logic1.ts"],
    deps = ["//feature4/helper"],
    declaration = True,
    tsconfig = {},
)

ts_project(
    name = "logic2",
    srcs = ["src/logic2.ts"],
    deps = ["//feature4/helper"],
    declaration = True,
    tsconfig = {},
)

