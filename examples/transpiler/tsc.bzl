"Adapter from the TypeScript CLI to the ts_project#transpiler/declaration_transpiler interface"

load("@npm//:typescript/package_json.bzl", typescript_bin = "bin")

# tsc configured with --outDir and --emitDeclarationOnly
def tsc_dts(name, srcs, out_dir, **kwargs):
    typescript_bin.tsc(
        name = name,
        srcs = srcs + ["tsconfig.json"],
        outs = ["%s/%s" % (out_dir, src.replace(".ts", ".d.ts")) for src in srcs],
        args = [
            "-p %s/tsconfig.json" % native.package_name(),
            "--emitDeclarationOnly",
            "--outDir %s/%s" % (native.package_name(), out_dir),
        ],
        **kwargs
    )

# tsc configured with --outDir and --declaration false
def tsc_js(name, srcs, out_dir, **kwargs):
    typescript_bin.tsc(
        name = name,
        srcs = srcs + ["tsconfig.json"],
        outs = ["%s/%s" % (out_dir, src.replace(".ts", ".js")) for src in srcs],
        args = [
            "-p %s/tsconfig.json" % native.package_name(),
            "--declaration",
            "false",
            "--outDir %s/%s" % (native.package_name(), out_dir),
        ],
        **kwargs
    )
