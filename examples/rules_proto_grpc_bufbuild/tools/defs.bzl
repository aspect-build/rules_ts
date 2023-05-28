"""
Rules for building @bufbuild compatible protos using @rules_proto_grpc helpers.
"""

load("@aspect_rules_js//js:defs.bzl", "js_library")
load("@rules_proto_grpc//:defs.bzl", "ProtoPluginInfo", "proto_compile_attrs", "proto_compile_impl")

# Using the plugins defined in the BUILD file, we define a new rule by parameterizing
# the proto_compile_impl which is provided by @rules_proto_grpc.
bufbuild_grpc_compile = rule(
    implementation = proto_compile_impl,
    attrs = dict(
        proto_compile_attrs,
        _plugins = attr.label_list(
            providers = [ProtoPluginInfo],
            default = [
                Label(":bufbuild_proto"),
                Label(":bufbuild_grpc"),
            ],
            doc = "List of protoc plugins to apply",
        ),
    ),
    toolchains = [
        str(Label("@rules_proto_grpc//protobuf:toolchain_type")),
    ],
)

# To help with consuming the proto outputs, we define this helper macro to wrap
# the compiler output into a js_library. The library depends on @bufbuild/protobuf
# because the compiled protos require it; by declaring the dependency here we don't
# have to remember to declare it everywhere else where we use the protos.
def ts_grpc_library(name, protos = [], **kwargs):
    grpc_compile_output = "%s_grpc" % name

    bufbuild_grpc_compile(
        name = grpc_compile_output,
        protos = protos,
        # You may want to change this.
        output_mode = "NO_PREFIX_FLAT",
    )

    js_library(
        name = name,
        srcs = [grpc_compile_output],
        deps = ["//:node_modules/@bufbuild/protobuf"],
        **kwargs
    )
