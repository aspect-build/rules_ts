"Adapter from the Babel CLI to the ts_project#transpiler interface"

load("@aspect_bazel_lib//lib:copy_file.bzl", "copy_file")
load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_to_bin")
load("@npm//examples:@babel/cli/package_json.bzl", "bin")

# buildifier: disable=function-docstring
def babel(name, srcs, out_dir = None, resolve_json = False, commonjs = False, **kwargs):
    # rules_js runs under the output tree in bazel-out/[arch]/bin
    # and we additionally chdir to the examples/ folder beneath that.
    execroot = "../../../.."

    outs = []

    # In this example we compile each file individually on .ts src files.
    # The src files must be .ts files known at the loading phase in order
    # to setup the babel compilation for each .ts file.
    #
    # You might instead use a single babel_cli call to compile
    # a directory of sources into an output directory,
    # but you'll need to:
    # - make sure the input directory only contains files listed in srcs
    # - make sure the js_outs are actually created in the expected path
    for idx, src in enumerate(srcs):
        # Support json sources as plain copied files
        if resolve_json and src.endswith(".json"):
            if out_dir:
                copy_file(
                    name = "{}_{}".format(name, idx),
                    src = src,
                    out = "%s/%s" % (out_dir, src),
                )
            else:
                copy_to_bin(
                    name = "{}_{}".format(name, idx),
                    srcs = [src],
                )
            outs.append(":{}_{}".format(name, idx))
            continue

        if src.endswith(".d.ts") or src.endswith(".d.mts"):
            continue

        if not (src.endswith(".ts") or src.endswith(".mts")):
            fail("babel example transpiler only supports source .[m]ts or .json files, found: %s" % src)

        out_pre = "%s/" % out_dir if out_dir else ""

        # Predict the output paths where babel will write
        js_out = out_pre + src.replace(".mts", ".mjs").replace(".ts", ".js")
        map_out = out_pre + src.replace(".mts", ".mjs.map").replace(".ts", ".js.map")

        # see https://babeljs.io/docs/en/babel-cli
        args = []

        # Inputs source files
        args.append("{}/$(location {})".format(execroot, src))

        # Output paths
        args.extend(["--out-file", "{}/$(location {})".format(execroot, js_out)])

        # Transpilation options
        args.append("--source-maps")
        args.append("--presets=@babel/preset-typescript")
        if commonjs:
            args.append("--plugins=@babel/plugin-transform-modules-commonjs")

        bin.babel(
            name = "{}_{}".format(name, idx),
            srcs = [
                src,
                "//examples:node_modules/@babel/preset-typescript",
                "//examples:node_modules/@babel/plugin-transform-modules-commonjs",
            ],
            chdir = "examples",
            outs = [js_out, map_out],
            args = args,
            **kwargs
        )

        outs.append(js_out)
        outs.append(map_out)

    # The target whose default outputs are the js files which ts_project() will reference
    native.filegroup(
        name = name,
        srcs = outs,
    )
