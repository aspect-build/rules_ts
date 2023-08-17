"Private implementation details for ts_proto_library"

load("@bazel_skylib//lib:paths.bzl", "paths")
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

    if ctx.attr.has_services:
        args.add_joined(["--plugin", "protoc-gen-connect-es", ctx.executable.protoc_gen_connect_es.path], join_with = "=")
        for (key, value) in options.items():
            args.add_joined(["--connect-es_opt", key, value], join_with = "=")
        args.add_joined(["--connect-es_out", ctx.bin_dir.path], join_with = "=")

    args.add_all(inputs)
    ctx.actions.run(
        executable = ctx.executable.protoc,
        progress_message = "Generating .js/.d.ts from %{label}",
        outputs = outputs,
        inputs = inputs,
        arguments = [args],
        tools = [ctx.executable.protoc_gen_es] + (
            [ctx.executable.protoc_gen_connect_es] if ctx.attr.has_services else []
        ),
        env = {"BAZEL_BINDIR": ctx.bin_dir.path},
    )

def _declare_outs(ctx, proto_srcs, ext):
    """
    Predict the outputs the plugins will write.

    i.e. for [//path/to:subdir/my.proto] we should produce [subdir/my_pb.js]
    """
    result = [
        ctx.actions.declare_file(paths.relativize(s.short_path, ctx.label.package).replace(".proto", "_pb" + ext))
        for s in proto_srcs
    ]
    if ctx.attr.has_services:
        result.extend([
            ctx.actions.declare_file(paths.relativize(s.short_path, ctx.label.package).replace(".proto", "_connect" + ext))
            for s in proto_srcs
        ])
    return result

def _ts_proto_library_impl(ctx):
    proto_in = ctx.attr.proto[ProtoInfo].direct_sources
    js_outs = _declare_outs(ctx, proto_in, ".js")
    dts_outs = _declare_outs(ctx, proto_in, ".d.ts")

    _protoc_action(ctx, proto_in, js_outs + dts_outs)

    return [
        DefaultInfo(
            files = depset(js_outs),
        ),
        OutputGroupInfo(
            types = depset(dts_outs),
        ),
    ]

ts_proto_library = rule(
    implementation = _ts_proto_library_impl,
    attrs = {
        "has_services": attr.bool(
            doc = "whether to generate service stubs with gen-connect-es",
            default = True,
        ),
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
