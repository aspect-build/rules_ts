"Private implementation details for ts_proto_library"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "COPY_FILE_TO_BIN_TOOLCHAINS")
load("@aspect_bazel_lib//lib:platform_utils.bzl", "platform_utils")
load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load("@rules_proto//proto:proto_common.bzl", proto_toolchains = "toolchains")

_PROTO_TOOLCHAIN_TYPE = "@rules_proto//proto:toolchain_type"

def _windows_path_normalize(path):
    """Changes forward slashs to backslashs for Windows paths."""
    host_is_windows = platform_utils.host_platform_is_windows()
    if host_is_windows:
        return path.replace("/", "\\")
    return path

# Vendored: https://github.com/protocolbuffers/protobuf/blob/v31.1/bazel/common/proto_common.bzl#L15-L23
def _import_virtual_proto_path(path):
    """Imports all paths for virtual imports.

      They're of the form:
      'bazel-out/k8-fastbuild/bin/external/foo/e/_virtual_imports/e' or
      'bazel-out/foo/k8-fastbuild/bin/e/_virtual_imports/e'"""
    if path.count("/") > 4:
        return "-I%s" % path
    return None

# Vendored: https://github.com/protocolbuffers/protobuf/blob/v31.1/bazel/common/proto_common.bzl#L25-L34
def _import_repo_proto_path(path):
    """Imports all paths for generated files in external repositories.

      They are of the form:
      'bazel-out/k8-fastbuild/bin/external/foo' or
      'bazel-out/foo/k8-fastbuild/bin'"""
    path_count = path.count("/")
    if path_count > 2 and path_count <= 4:
        return "-I%s" % path
    return None

# Vendored: https://github.com/protocolbuffers/protobuf/blob/v31.1/bazel/common/proto_common.bzl#L36-L46
def _import_main_output_proto_path(path):
    """Imports all paths for generated files or source files in external repositories.

      They're of the form:
      'bazel-out/k8-fastbuild/bin'
      'external/foo'
      '../foo'
    """
    if path.count("/") <= 2 and path != ".":
        return "-I%s" % path
    return None

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

    # When proto_srcs is not provided, use direct_sources (which handles virtual imports correctly)
    proto_sources = ctx.files.proto_srcs if ctx.attr.proto_srcs else proto_info.direct_sources
    inputs = depset(proto_sources, transitive = [proto_info.transitive_descriptor_sets])

    options = dict({
        "keep_empty_files": True,
        "target": "js+dts",
    }, **ctx.attr.protoc_gen_options)

    if not options["keep_empty_files"]:
        fail("protoc_gen_options.keep_empty_files must be True")
    if options["target"] != "js+dts":
        fail("protoc_gen_options.target must be 'js+dts'")

    # Compute the output directory. When strip_import_prefix is used, we need to adjust
    # the es_out path so that outputs land in the rule's package directory.
    stripped_prefix = _get_stripped_prefix(ctx, proto_sources)
    es_out = ctx.bin_dir.path
    if stripped_prefix:
        es_out = ctx.bin_dir.path + "/" + stripped_prefix

    args = ctx.actions.args()
    args.add_joined(["--plugin", "protoc-gen-es", _windows_path_normalize(ctx.executable.protoc_gen_es.path)], join_with = "=")
    for (key, value) in options.items():
        args.add_joined(["--es_opt", key, value], join_with = "=")
    args.add_joined(["--es_out", es_out], join_with = "=")

    if ctx.attr.gen_connect_es:
        args.add_joined(["--plugin", "protoc-gen-connect-es", _windows_path_normalize(ctx.executable.protoc_gen_connect_es.path)], join_with = "=")
        for (key, value) in options.items():
            args.add_joined(["--connect-es_opt", key, value], join_with = "=")
        args.add_joined(["--connect-es_out", es_out], join_with = "=")

    if ctx.attr.gen_connect_query:
        args.add_joined(["--plugin", "protoc-gen-connect-query", _windows_path_normalize(ctx.executable.protoc_gen_connect_query.path)], join_with = "=")
        for (key, value) in options.items():
            args.add_joined(["--connect-query_opt", key, value], join_with = "=")
        args.add_joined(["--connect-query_out", es_out], join_with = "=")

    args.add("--descriptor_set_in")
    args.add_joined(proto_info.transitive_descriptor_sets, join_with = ctx.configuration.host_path_separator)

    # Vendored: https://github.com/protocolbuffers/protobuf/blob/v31.1/bazel/common/proto_common.bzl#L193-L204
    # Protoc searches for .protos -I paths in order they are given and then
    # uses the path within the directory as the package.
    # This requires ordering the paths from most specific (longest) to least
    # specific ones, so that no path in the list is a prefix of any of the
    # following paths in the list.
    # For example: 'bazel-out/k8-fastbuild/bin/external/foo' needs to be listed
    # before 'bazel-out/k8-fastbuild/bin'. If not, protoc will discover file under
    # the shorter path and use 'external/foo/...' as its package path.
    args.add_all(proto_info.transitive_proto_path, map_each = _import_virtual_proto_path)
    args.add_all(proto_info.transitive_proto_path, map_each = _import_repo_proto_path)
    args.add_all(proto_info.transitive_proto_path, map_each = _import_main_output_proto_path)
    args.add("-I.")  # Needs to come last

    args.add_all(proto_sources)

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
        use_default_shell_env = True,
    )

def _get_proto_import_path(src):
    """Extracts the proto import path from a source file.

    When strip_import_prefix is used, proto sources are in a _virtual_imports directory.
    For example: bazel-out/.../pkg/_virtual_imports/foo_proto/stripped/path/foo.proto
    The import path is: stripped/path/foo.proto

    For regular protos without stripping, the source path is the import path.
    """
    src_path = src.path
    if "_virtual_imports/" in src_path:
        # Extract path after _virtual_imports/<target_name>/
        idx = src_path.find("_virtual_imports/")
        remainder = src_path[idx + len("_virtual_imports/"):]

        # Skip the target name directory
        slash_idx = remainder.find("/")
        if slash_idx >= 0:
            return remainder[slash_idx + 1:]

    # Regular case: use the short_path (relative to workspace root)
    return src.short_path

def _get_stripped_prefix(ctx, proto_sources):
    """Computes the prefix that was stripped by strip_import_prefix.

    Returns the prefix to add to --es_out so outputs land in the rule's package.
    For example, if the rule is in examples/proto_grpc/stripping and the proto
    import path is proto_grpc/stripping/s.proto, returns "examples".
    """
    if not proto_sources:
        return ""

    src = proto_sources[0]
    if "_virtual_imports/" not in src.path:
        return ""

    import_path = _get_proto_import_path(src)
    import_dir = import_path.rsplit("/", 1)[0] if "/" in import_path else ""
    pkg = ctx.label.package

    # Check if the package ends with the import directory
    if import_dir and pkg.endswith(import_dir):
        prefix = pkg[:-len(import_dir)].rstrip("/")
        return prefix
    return ""

def _declare_outs(ctx, info, ext):
    proto_sources = info.direct_sources

    def _declare_generated_file(src, suffix):
        # Always declare outputs using basename, in the rule's package
        return ctx.actions.declare_file(src.basename[:-(len(src.extension) + 1)] + suffix)

    outs = [_declare_generated_file(src, "_pb" + ext) for src in proto_sources]
    if ctx.attr.gen_connect_es:
        outs.extend([_declare_generated_file(src, "_connect" + ext) for src in proto_sources])
    if ctx.attr.gen_connect_query:
        proto_source_map = {src.basename: src for src in proto_sources}

        # FIXME: we should refer to source files via labels instead of filenames
        for proto, services in ctx.attr.gen_connect_query_service_mapping.items():
            if not proto in proto_source_map:
                fail("{} is not provided by proto_srcs".format(proto))

            # src = proto_source_map.get(proto)
            prefix = proto.replace(".proto", "")
            for service in services:
                outs.append(ctx.actions.declare_file(
                    "{}-{}_connectquery{}".format(prefix, service, ext),
                    # sibling = src
                ))

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
        "proto_srcs": attr.label_list(
            doc = "proto source files to generate JS/DTS for",
            allow_files = [".proto"],
        ),
        "gen_connect_es": attr.bool(
            doc = """whether to generate service stubs with gen-connect-es
            Deprecated: no longer needed, see https://github.com/connectrpc/connect-es/blob/main/MIGRATING.md""",
            default = False,
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
            doc = """protoc plugin to generate services
            deprecated: no longer needed now that @bufbuild/protoc-gen-es v2 generates service definitions""",
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
