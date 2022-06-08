load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

write_file(
    name = "bigts",
    out = "big.ts",
    content = [
        "export const a{0}: number = {0}".format(x)
        for x in range(10000)
    ],
)

ts_project(
    name = "feature3",
    srcs = ["index.ts", "big.ts"],
    declaration = True,
    visibility = ["//visibility:public"],   
    tsconfig = {},
)

