load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

ts_project(
    name = "ts",
    srcs = glob(
        ["*.ts"], 
        exclude = ["lib.ts", "fail.ts"]
    ),
    supports_workers = True,
    deps = [
        ":lib",
        "//feature"
    ]
)

ts_project(
    name = "lib",
    srcs = ["lib.ts"],
    declaration = True,
    supports_workers = True,
    tsconfig ={
        "compilerOptions": {
            "declaration": True
        }
    }
)

ts_project(
    name = "should_fail",
    srcs = ["fail.ts"],
    supports_workers = True,
)