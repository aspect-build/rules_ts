load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_proto//proto:defs.bzl", "proto_library")
load("@aspect_rules_ts//ts:proto.bzl", "ts_proto_library")
load("@npm//:defs.bzl", "npm_link_all_packages")

package(default_visibility = ["//visibility:public"])

npm_link_all_packages(name = "node_modules")

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
)

ts_proto_library(
    name = "foo_ts_proto",
    has_services = False,
    copy_files = False,
    node_modules = ":node_modules",
    proto = ":foo_proto",
)

ts_project(
    name = "ts",
    srcs = ["foo.ts"],
    extends = "tsconfig.json",
    transpiler = "tsc",
    tsconfig = {
        "extends": "tsconfig.json",
    },
)

build_test(
    name = "test",
    targets = [":ts"],
)
