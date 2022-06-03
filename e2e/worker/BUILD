load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

ts_project(
    name = "ts",
    srcs = glob(["*.ts"], exclude = ["lib.ts", "fail.ts"]),
    deps = [
        "//feature",
        "//feature1",
        "//feature2",
        "//feature3",
        "//feature4"
    ],
    supports_workers = True,
)


ts_project(
    name = "lib",
    srcs = ["lib.ts"],
    supports_workers = True,
    declaration = True,
    tsconfig = {}
)

ts_project(
    name = "should_fail",
    srcs = ["fail.ts"],
    supports_workers = True,
    declaration = True,
    tsconfig = {}
)

build_test(
    name = "test",
    targets = [
        ":ts",
        ":lib",
    ],
)
