"Private implementation details for ts_proto_library"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "COPY_FILE_TO_BIN_TOOLCHAINS")
load("@aspect_bazel_lib//lib:platform_utils.bzl", "platform_utils")
load("@rules_proto//proto:defs.bzl", "ProtoInfo", "proto_common")
load("@rules_proto//proto:proto_common.bzl", proto_toolchains = "toolchains")

_PROTO_TOOLCHAIN_TYPE = "@rules_proto//proto:toolchain_type"

def _windows_path_normalize(path):
    """Changes forward slashs to backslashs for Windows paths."""
    host_is_windows = platform_utils.host_platform_is_windows()
    if host_is_windows:
        return path.replace("/", "\\")
    return path

# buildifier: disable=function-docstring-header
def _protoc_action(ctx, proto_info, outputs):
    """Create an action like
    bazel-out/k8-opt-exec-2B5CBBC6/bin/external/com_google_protobuf/protoc $@' '' \
      '--plugin=protoc-gen-es=bazel-out/k8-opt-exec-2B5CBBC6/bin/plugin/bufbuild/protoc-gen-es.sh' \
      '--es_opt=keep_empty_files=true' '--es_opt=target=ts' \
      '--es_out=bazel-out/k8-fastbuild/bin' \
      '--descriptor_set_in=bazel-out/k8-fastbuild/bin/external/com_google_protobuf/timestamp_proto-descriptor-set.proto.bin:bazel-out/k8-fastbuild/bin/example/thing/thing_proto-descriptor-set.proto.bin:bazel-out/k8-fastbuild/bin/example/place/place_proto-descriptor-set.proto.bin:bazel-out/k8-fastbuild/bin/example/person/person_proto-descriptor-set.proto.bin' \
      example/person/person.proto
    """
    inputs = depset(proto_info.direct_sources, transitive = [proto_info.transitive_descriptor_sets])

    options = dict({
        "keep_empty_files": True,
        "target": "js+dts",
    }, **ctx.attr.protoc_gen_options)

    if not options["keep_empty_files"]:
        fail("protoc_gen_options.keep_empty_files must be True")
    if options["target"] != "js+dts":
        fail("protoc_gen_options.target must be 'js+dts'")

    args = ctx.actions.args()
    args.add_joined(["--plugin", "protoc-gen-es", _windows_path_normalize(ctx.executable.protoc_gen_es.path)], join_with = "=")
    for (key, value) in options.items():
        args.add_joined(["--es_opt", key, value], join_with = "=")
    args.add_joined(["--es_out", ctx.bin_dir.path], join_with = "=")

    if ctx.attr.gen_connect_es:
        args.add_joined(["--plugin", "protoc-gen-connect-es", _windows_path_normalize(ctx.executable.protoc_gen_connect_es.path)], join_with = "=")
        for (key, value) in options.items():
            args.add_joined(["--connect-es_opt", key, value], join_with = "=")
        args.add_joined(["--connect-es_out", ctx.bin_dir.path], join_with = "=")

    if ctx.attr.gen_connect_query:
        args.add_joined(["--plugin", "protoc-gen-connect-query", _windows_path_normalize(ctx.executable.protoc_gen_connect_query.path)], join_with = "=")
        for (key, value) in options.items():
            args.add_joined(["--connect-query_opt", key, value], join_with = "=")
        args.add_joined(["--connect-query_out", ctx.bin_dir.path], join_with = "=")

    args.add("--descriptor_set_in")
    args.add_joined(proto_info.transitive_descriptor_sets, join_with = ":")

    args.add_all(proto_info.direct_sources)

    proto_toolchain_enabled = len(proto_toolchains.use_toolchain(_PROTO_TOOLCHAIN_TYPE)) > 0
    ctx.actions.run(
        executable = ctx.toolchains[_PROTO_TOOLCHAIN_TYPE].proto.proto_compiler if proto_toolchain_enabled else ctx.executable.protoc,
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

    return [
        DefaultInfo(
            files = depset(js_outs + dts_outs),
        ),
    ]

ts_proto_library = rule(
    implementation = _ts_proto_library_impl,
    attrs = dict({
        "gen_connect_es": attr.bool(
            doc = "whether to generate service stubs with gen-connect-es",
            default = True,
        ),
        "gen_connect_query": attr.bool(
            doc = "whether to generate TanStack Query clients with gen-connect-query",
            default = False,
        ),
        "gen_connect_query_service_mapping": attr.string_list_dict(
            doc = "mapping from protos to services those protos contain used to predict output file names for gen-connect-query",
            default = {},
        ),
        "proto": attr.label(
            doc = "proto_library to generate JS/DTS for",
            providers = [ProtoInfo],
            mandatory = True,
        ),
        "protoc_gen_options": attr.string_dict(
            doc = "dict of protoc_gen_es options",
            default = {},
        ),
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
            doc = "protoc plugin to generate TanStack Query services",
            executable = True,
            cfg = "exec",
        ),
    }, **proto_toolchains.if_legacy_toolchain({
        "protoc": attr.label(default = "@com_google_protobuf//:protoc", executable = True, cfg = "exec"),
    })),
    toolchains = COPY_FILE_TO_BIN_TOOLCHAINS + proto_toolchains.use_toolchain(_PROTO_TOOLCHAIN_TYPE),
)
