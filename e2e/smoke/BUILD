load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@aspect_rules_ts//ts:proto.bzl", "ts_proto_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@npm//:defs.bzl", "npm_link_all_packages")
load("@protobuf//bazel:proto_library.bzl", "proto_library")

package(default_visibility = ["//visibility:public"])

npm_link_all_packages(name = "node_modules")

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
)

ts_proto_library(
    name = "foo_ts_proto",
    copy_files = False,
    gen_connect_es = False,
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
