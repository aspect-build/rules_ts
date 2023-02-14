load("@npm//:defs.bzl", "npm_link_all_packages")
load("@aspect_rules_js//npm:defs.bzl", "npm_package")
load("@aspect_rules_ts//ts:defs.bzl", "ts_config")

npm_link_all_packages()

ts_config(
    name = "tsconfig",
    src = "tsconfig.json",
    deps = [
        ":node_modules/@tsconfig/node18",
    ],
)

npm_package(
    name = "linked_tsconfig",
    srcs = [":tsconfig"],
    visibility = ["//visibility:public"],
)
