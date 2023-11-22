"""
Macro wrappers around rules_js's `js_binary` and `js_test` that improve the DX of stack traces by automatically
registering source-map-support and removing the runfiles directory prefix.

Use them wherever you would use rules_js's `js_binary` and `js_test`.
"""

load("@aspect_rules_js//js:defs.bzl", _js_binary = "js_binary", _js_test = "js_test")

def js_binary(data = [], node_options = [], **kwargs):
    _js_binary(
        data = [
            "//examples:node_modules/source-map-support",
            "//examples/source_map_support:stack-trace-support",
        ] + data,
        node_options = select({
            "@aspect_bazel_lib//lib:bzlmod": ["--require", "$$RUNFILES/_main/examples/source_map_support/stack-trace-support"] + node_options,
            "//conditions:default": ["--require", "$$RUNFILES/aspect_rules_ts/examples/source_map_support/stack-trace-support"] + node_options,
        }),
        **kwargs
    )

def js_test(data = [], node_options = [], **kwargs):
    _js_test(
        data = [
            "//examples:node_modules/source-map-support",
            "//examples/source_map_support:stack-trace-support",
        ] + data,
        node_options = select({
            "@aspect_bazel_lib//lib:bzlmod": ["--require", "$$RUNFILES/_main/examples/source_map_support/stack-trace-support"] + node_options,
            "//conditions:default": ["--require", "$$RUNFILES/aspect_rules_ts/examples/source_map_support/stack-trace-support"] + node_options,
        }),
        **kwargs
    )
