load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:build_test.bzl", "build_test")

ts_project(
    name = "ts",
    srcs = glob(
        ["*.ts"], 
        exclude = ["lib.ts", "fail.ts"]
    ),
    deps = [
        "//feature",
        "//feature1",
        "//feature2",
        "//feature3",
        "//feature4"
    ]
)


ts_project(
    name = "lib",
    srcs = ["lib.ts"],
    declaration = True,
    tsconfig = {}
)

ts_project(
    name = "should_fail",
    srcs = ["fail.ts"],
    declaration = True,
    tsconfig = {},
    tags = ["manual"]
)

build_test(
    name = "test",
    targets = [
        ":ts",
        ":lib",
    ],
)
