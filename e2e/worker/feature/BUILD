load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

ts_project(
    name = "feature",
    srcs = ["index.ts"],
    deps = [
        ":sub"
    ],
    supports_workers = True,
    declaration = True,
    visibility = ["//visibility:public"]
)


ts_project(
    name = "sub",
    srcs = ["sub/index.ts"],
    supports_workers = False,
    declaration = True
)