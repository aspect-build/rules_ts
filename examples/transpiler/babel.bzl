"Adapter from the Babel CLI to the ts_project#transpiler interface"

load("@aspect_rules_js//js:defs.bzl", "js_library")
load("@npm//examples:@babel/cli/package_json.bzl", "bin")

# buildifier: disable=function-docstring
def babel(name, srcs, **kwargs):
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
        if not src.endswith(".ts"):
            fail("babel example transpiler only supports source .ts files")

        js_out = src.replace(".ts", ".js")
        map_out = src.replace(".ts", ".js.map")

        # see https://babeljs.io/docs/en/babel-cli
        args = [
            "{}/$(location {})".format(execroot, src),
            "--presets=@babel/preset-typescript",
            "--out-file",
            "{}/$(location {})".format(execroot, js_out),
            "--source-maps",
        ]

        bin.babel(
            name = "{}_{}".format(name, idx),
            srcs = [
                src,
                "//examples:node_modules/@babel/preset-typescript",
            ],
            chdir = "examples",
            outs = [js_out, map_out],
            args = args,
            **kwargs
        )

        outs.append(js_out)
        outs.append(map_out)

    # The target producing the js files which ts_project() will reference
    js_library(
        name = name,
        srcs = outs,
    )
