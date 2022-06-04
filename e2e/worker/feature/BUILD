load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

ts_project(
    name = "feature",
    srcs = ["index.ts"],
    declaration = True,
    supports_workers = True,
    visibility = ["//visibility:public"],   
    deps = [
        ":sub",
    ],
)

ts_project(
    name = "sub",
    srcs = glob(["sub/*.ts"]),
    tsconfig = {},
    declaration = True,
    resolve_json_module = True,
    supports_workers = True,
    validate = False,
)
