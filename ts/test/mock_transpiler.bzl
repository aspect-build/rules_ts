"Fixture to demonstrate a custom transpiler for ts_project"

load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

_DUMMY_SOURCEMAP = """{"version":3,"sources":["%s"],"mappings":"AAAO,KAAK,CAAC","file":"in.js","sourcesContent":["fake"]}"""

def mock(name, srcs, js_outs, map_outs, **kwargs):
    """Mock transpiler macro.

    In real usage you would wrap a rule like
    https://github.com/aspect-build/rules_swc/blob/main/docs/swc.md

    Args:
        name: rule name prefix
        srcs: ts sources
        js_outs: js files to generate
        map_outs: map files to generate
        **kwargs: unused
    """

    for i, s in enumerate(srcs):
        copy_file(
            name = "_{}_{}_js".format(name, s),
            src = s,
            out = js_outs[i],
        )

        if i < len(map_outs):
            write_file(
                name = "_{}_{}_map".format(name, s),
                out = map_outs[i],
                content = [_DUMMY_SOURCEMAP % s],
            )
