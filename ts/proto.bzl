"""Protobuf and gRPC support for TypeScript.

See
- https://connectrpc.com/docs/web/getting-started
- https://connectrpc.com/docs/node/getting-started
"""

load("@protobuf//bazel/toolchains:proto_lang_toolchain.bzl", "proto_lang_toolchain")
load("//ts/private:ts_proto_library.bzl", "GEN_ES_PLUGIN_TOOLCHAIN")

def ts_protoc_plugin_toolchain(name, protoc_plugin, runtime, command_line = ""):
    """Declare a toolchain for the TypeScript gRPC protoc plugin.

    NB: the toolchain produced by this macro is actually named [name]_toolchain, so THAT is what you must register.
    Even better, make a dedicated 'toolchains' directory and put all your toolchains in there, then register them all with 'register_toolchains("//path/to/toolchains:all")'.
    """
    proto_lang_toolchain(
        name = name,
        plugin = protoc_plugin,
        toolchain_type = GEN_ES_PLUGIN_TOOLCHAIN,
        command_line = command_line,
        runtime = runtime,
    )

# FIXME: still want to have .d.ts files placed in the source tree, by diff.bzl
#     if not copy_files:
#         return
#     if not files_to_copy:
#         if not proto_srcs:
#             fail("Either proto_srcs should be set, or copy_files should be False")
#         files_to_copy = [s.replace(".proto", "_pb.d.ts") for s in proto_srcs]
#         if gen_connect_es:
#             files_to_copy.extend([s.replace(".proto", "_connect.d.ts") for s in proto_srcs])
#         if gen_connect_query:
#             for proto, services in gen_connect_query_service_mapping.items():
#                 files_to_copy.extend([proto.replace(".proto", "-{}_connectquery.d.ts".format(s)) for s in services])

#     files_target = "_{}.filegroup".format(name)
#     dir_target = "_{}.directory".format(name)
#     copy_target = "{}.copy".format(name)

#     native.filegroup(
#         name = files_target,
#         srcs = [name],
#         output_group = "types",
#     )

#     copy_to_directory(
#         name = dir_target,
#         srcs = [files_target],
#         root_paths = ["**"],
#     )

#     write_source_files(
#         name = copy_target,
#         files = {
#             f: make_directory_path("_{}_dirpath".format(f), dir_target, f)
#             for f in files_to_copy
#         },
#     )
