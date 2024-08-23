load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@aspect_rules_ts//ts:proto.bzl", "ts_proto_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@npm//:defs.bzl", "npm_link_all_packages")
load("@rules_proto//proto:defs.bzl", "proto_library")

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

# Demonstrate how to use a different typescript where required
# Picks up TypeScript 3.9.9 defined in MODULE.bazel
ts_project(
    name = "ts3",
    srcs = ["foo.ts"],
    extends = "tsconfig.json",
    out_dir = "ts3_out",
    transpiler = "tsc",
    tsc = "@npm_typescript3//:tsc",
    tsconfig = {
        "extends": "tsconfig.json",
    },
)

build_test(
    name = "test",
    targets = [":ts"],
)
