load("@aspect_rules_js//js:defs.bzl", "js_library")
load("@aspect_rules_js//npm:defs.bzl", "npm_package")

load("@npm//:defs.bzl", "npm_link_all_packages")
npm_link_all_packages()


js_library(
    name = "b_lib",
    srcs = [
        "index.d.ts",
        "index.js",
    ]
)

npm_package(
    name = "b",
    srcs = [
        ":b_lib",
    ],
    visibility = ["//visibility:public"],
)
