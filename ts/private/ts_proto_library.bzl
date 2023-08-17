"Private implementation details for ts_proto_library"

load("@rules_proto//proto:defs.bzl", "ProtoInfo")

# buildifier: disable=function-docstring-header
def _protoc_action(ctx, inputs, outputs, options = {
    "keep_empty_files": True,
    "target": "js+dts",
}):
    """Create an action like
    bazel-out/k8-opt-exec-2B5CBBC6/bin/external/com_google_protobuf/protoc $@' '' \
      '--plugin=protoc-gen-es=bazel-out/k8-opt-exec-2B5CBBC6/bin/plugin/bufbuild/protoc-gen-es.sh' \
      '--es_opt=keep_empty_files=true' '--es_opt=target=ts' \
      '--es_out=bazel-out/k8-fastbuild/bin' \
      '--descriptor_set_in=bazel-out/k8-fastbuild/bin/external/com_google_protobuf/timestamp_proto-descriptor-set.proto.bin:bazel-out/k8-fastbuild/bin/example/thing/thing_proto-descriptor-set.proto.bin:bazel-out/k8-fastbuild/bin/example/place/place_proto-descriptor-set.proto.bin:bazel-out/k8-fastbuild/bin/example/person/person_proto-descriptor-set.proto.bin' \
      example/person/person.proto
    """
    args = ctx.actions.args()
    args.add_joined(["--plugin", "protoc-gen-es", ctx.executable.protoc_gen_es.path], join_with = "=")
    for (key, value) in options.items():
        args.add_joined(["--es_opt", key, value], join_with = "=")
    args.add_joined(["--es_out", ctx.bin_dir.path], join_with = "=")
    args.add_all(inputs)
    ctx.actions.run(
        executable = ctx.executable.protoc,
        progress_message = "Generating .js/.d.ts from %{label}",
        outputs = outputs,
        inputs = inputs,
        arguments = [args],
        tools = [
            ctx.executable.protoc_gen_es,
        ],
        env = {
            #"RUNFILES": "thing",
            "BAZEL_BINDIR": ctx.bin_dir.path,
        },
    )

def _ts_proto_library_impl(ctx):
    proto_in = ctx.attr.proto[ProtoInfo].direct_sources
    js_out = ctx.actions.declare_file("logger_pb.js")
    dts_out = ctx.actions.declare_file("logger_pb.d.ts")
    _protoc_action(ctx, proto_in, [js_out, dts_out])
    return [
        DefaultInfo(
            files = depset([js_out, dts_out]),
        ),
    ]

ts_proto_library = rule(
    implementation = _ts_proto_library_impl,
    attrs = {
        "proto": attr.label(
            doc = "proto_library to generate JS/DTS for",
            providers = [ProtoInfo],
            mandatory = True,
        ),
        "protoc": attr.label(default = "@com_google_protobuf//:protoc", executable = True, cfg = "exec"),
        "protoc_gen_es": attr.label(
            doc = "protoc plugin to generate messages",
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
        "protoc_gen_connect_es": attr.label(
            doc = "protoc plugin to generate services",
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)
