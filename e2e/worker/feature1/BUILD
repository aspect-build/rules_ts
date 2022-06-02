load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

write_file(
    name = "bigts",
    out = "big.ts",
    content = [
        "export const a{0}: number = {0}".format(x)
        for x in range(100000)
    ],
)

ts_project(
    name = "feature1",
    srcs = ["index.ts", "big.ts"],
    declaration = True,
    supports_workers = True,
    visibility = ["//visibility:public"],   
    tsconfig = {},
)
