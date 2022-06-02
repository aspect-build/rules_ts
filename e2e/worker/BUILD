load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

ts_project(
    name = "ts",
    srcs = glob(["*.ts"], exclude = ["lib.ts" ]),
    deps = [
        ":lib",
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
    srcs = ["lib.ts" ],
    supports_workers = True,
    declaration = True,
    tsconfig = {}
)