load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@npm//:defs.bzl", "link_js_packages")

link_js_packages()

ts_project(
    name = "ts",
    srcs = ["foo.ts"],
    deps = ["@npm//@types/node"],
)
