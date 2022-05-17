load("@aspect_rules_js//js:defs.bzl", "js_package")
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

js_package(
    name = "foo",
    srcs = ["foo.js"],
)

ts_project(
    name = "ts",
    srcs = ["bar.ts"],
    deps = ["foo"],
)
