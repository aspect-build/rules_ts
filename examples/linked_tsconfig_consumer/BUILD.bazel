load("@npm//:defs.bzl", "npm_link_all_packages")
load("@aspect_rules_ts//ts:defs.bzl", "ts_config", "ts_project")

npm_link_all_packages()

ts_config(
    name = "tsconfig",
    src = "tsconfig.json",
    deps = [
        ":node_modules/@lib/tsconfig",
    ],
)

ts_project(
    name = "lib",
    srcs = [
        "index.ts",
    ],
    tsconfig = ":tsconfig",
    deps = [
        ":node_modules/@types/node",
    ],
)
