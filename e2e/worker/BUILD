load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_to_bin")
load("@npm//:defs.bzl", "npm_link_all_packages")

package(default_visibility = ["//:__subpackages__"])

npm_link_all_packages(name = "node_modules")

copy_to_bin(
    name = "tsconfig",
    srcs = ["tsconfig.json"],
)

ts_project(
    name = "ts",
    srcs = glob(
        ["*.ts"],
        exclude = [
            "lib.ts",
        ],
    ),
    deps = [
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
