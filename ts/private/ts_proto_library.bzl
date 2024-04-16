"Private implementation details for ts_proto_library"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "COPY_FILE_TO_BIN_TOOLCHAINS")
load("@aspect_rules_js//js:libs.bzl", "js_lib_helpers")
load("@aspect_rules_js//js:providers.bzl", "JsInfo", "js_info")
load("@rules_proto//proto:defs.bzl", "ProtoInfo", "proto_common")

# buildifier: disable=function-docstring-header
def _protoc_action(ctx, proto_info, outputs, options = {
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
    inputs = depset(proto_info.direct_sources, transitive = [proto_info.transitive_descriptor_sets])

    args = ctx.actions.args()
    args.add_joined(["--plugin", "protoc-gen-es", ctx.executable.protoc_gen_es.path], join_with = "=")
    for (key, value) in options.items():
        args.add_joined(["--es_opt", key, value], join_with = "=")
    args.add_joined(["--es_out", ctx.bin_dir.path], join_with = "=")

    if ctx.attr.gen_connect_es:
        args.add_joined(["--plugin", "protoc-gen-connect-es", ctx.executable.protoc_gen_connect_es.path], join_with = "=")
        for (key, value) in options.items():
            args.add_joined(["--connect-es_opt", key, value], join_with = "=")
        args.add_joined(["--connect-es_out", ctx.bin_dir.path], join_with = "=")

    if ctx.attr.gen_connect_query:
        args.add_joined(["--plugin", "protoc-gen-connect-query", ctx.executable.protoc_gen_connect_query.path], join_with = "=")
        for (key, value) in options.items():
            args.add_joined(["--connect-query_opt", key, value], join_with = "=")
        args.add_joined(["--connect-query_out", ctx.bin_dir.path], join_with = "=")

    args.add("--descriptor_set_in")
    args.add_joined(proto_info.transitive_descriptor_sets, join_with = ":")

    args.add_all(proto_info.direct_sources)

    ctx.actions.run(
        executable = ctx.executable.protoc,
        progress_message = "Generating .js/.d.ts from %{label}",
        outputs = outputs,
        inputs = inputs,
        mnemonic = "ProtocGenEs",
        arguments = [args],
        tools = [ctx.executable.protoc_gen_es] + (
            [ctx.executable.protoc_gen_connect_es] if ctx.attr.gen_connect_es else []
        ) + (
            [ctx.executable.protoc_gen_connect_query] if ctx.attr.gen_connect_query else []
        ),
        env = {"BAZEL_BINDIR": ctx.bin_dir.path},
    )

def _declare_outs(ctx, info, ext):
    outs = proto_common.declare_generated_files(ctx.actions, info, "_pb" + ext)
    if ctx.attr.gen_connect_es:
        outs.extend(proto_common.declare_generated_files(ctx.actions, info, "_connect" + ext))
    if ctx.attr.gen_connect_query:
        for proto, services in ctx.attr.gen_connect_query_service_mapping.items():
            for service in services:
                prefix = proto.replace(".proto", "")
                outs.append(ctx.actions.declare_file("{}-{}_connectquery{}".format(prefix, service, ext)))

    return outs

def _ts_proto_library_impl(ctx):
    info = ctx.attr.proto[ProtoInfo]
    js_outs = _declare_outs(ctx, info, ".js")
    dts_outs = _declare_outs(ctx, info, ".d.ts")

    _protoc_action(ctx, info, js_outs + dts_outs)

    direct_srcs = depset(js_outs)
    direct_decls = depset(dts_outs)

    return [
        DefaultInfo(
            files = direct_srcs,
            runfiles = js_lib_helpers.gather_runfiles(
                ctx = ctx,
                sources = direct_srcs,
                data = [],
                deps = ctx.attr.deps,
            ),
        ),
        OutputGroupInfo(types = direct_decls),
        js_info(
            declarations = direct_decls,
            sources = direct_srcs,
            transitive_declarations = js_lib_helpers.gather_transitive_declarations(
                declarations = dts_outs,
                targets = ctx.attr.deps,
            ),
            transitive_sources = js_lib_helpers.gather_transitive_sources(
                sources = js_outs,
                targets = ctx.attr.deps,
            ),
        ),
    ]

ts_proto_library = rule(
    implementation = _ts_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            providers = [JsInfo],
            doc = "Other ts_proto_library rules. TODO: could we collect them with an aspect",
        ),
        "gen_connect_es": attr.bool(
            doc = "whether to generate service stubs with gen-connect-es",
            default = True,
        ),
        "gen_connect_query": attr.bool(
            doc = "whether to generate service stubs with gen-connect-query",
            default = False,
        ),
        "gen_connect_query_service_mapping": attr.string_list_dict(
            doc = "what services to generate for connect-query",
            default = {},
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
            executable = True,
            cfg = "exec",
        ),
        "protoc_gen_connect_query": attr.label(
            doc = "protoc plugin to generate react query services",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = COPY_FILE_TO_BIN_TOOLCHAINS,
)
