load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_to_bin")
load("@npm//:defs.bzl", "npm_link_all_packages")

npm_link_all_packages(name = "node_modules")

ts_project(
    name = "ts",
    srcs = glob(
        ["*.ts"],
        exclude = [
            "lib.ts",
            "fail.ts",
        ],
    ),
    deps = [
        ":node_modules/@nestjs/common",
        ":node_modules/@nestjs/core",
        ":node_modules/@types/debug",
        ":node_modules/@types/node",
        ":node_modules/debug",
        ":node_modules/rxjs",
        "//feature",
        "//feature1",
        "//feature2",
        "//feature3",
        "//feature4",
    ],
)

ts_project(
    name = "lib",
    srcs = ["lib.ts"],
    declaration = True,
    tsconfig = {},
)

ts_project(
    name = "should_fail",
    srcs = ["fail.ts"],
    declaration = True,
    tags = ["manual"],
    tsconfig = {},
)

# this is here to ensure that package.json#type=module does not affect worker.
copy_to_bin(
    name = "copy_package",
    srcs = ["package.json"],
)

build_test(
    name = "test",
    targets = [
        ":copy_package",
        ":ts",
        ":lib",
    ],
)
