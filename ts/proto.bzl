"""# Protocol Buffers and gRPC

Note this is not included in `defs.bzl` to avoid eager loads of rules_proto for all rules_ts users.
"""

load("@aspect_bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")
load("@aspect_bazel_lib//lib:directory_path.bzl", "make_directory_path")
load("@aspect_bazel_lib//lib:write_source_files.bzl", "write_source_files")
load("//ts/private:ts_proto_library.bzl", ts_proto_library_rule = "ts_proto_library")

def ts_proto_library(name, gen_es_bin, gen_connect_es_bin = None, has_services = True, copy_files = True, files_to_copy = None, **kwargs):
    """
    A macro to generate JavaScript code and TypeScript typings from .proto files.

    Args:
        name: name of resulting ts_proto_library target
        gen_es_bin: the package.json "bin" entry for https://www.npmjs.com/package/@bufbuild/protoc-gen-es
            typically loaded with
            `load("@npm//path/to/pkg:@bufbuild/protoc-gen-es/package_json.bzl", gen_bin = "bin")`
        gen_connect_es_bin: the package.json "bin" entry for https://www.npmjs.com/package/@bufbuild/protoc-gen-connect-es
            typically loaded with
            `load("@npm//path/to/pkg:@bufbuild/protoc-gen-connect-es/package_json.bzl", gen_connect_bin = "bin")`
        has_services: whether the proto file contains a service, and therefore *_connect.{js,d.ts} should be written.
        copy_files: whether to copy the resulting .d.ts files back to the source tree, for the editor to locate them.
        files_to_copy: which files from the protoc output to copy. By default, scans for *.proto in the current package
            and replaces with the typical output filenames.
        **kwargs: additional named arguments to the ts_proto_library rule
    """
    protoc_gen_es_target = "_{}.gen_es".format(name)
    protoc_gen_connect_es_target = "_{}.gen_connect_es".format(name)

    gen_es_bin.protoc_gen_es_binary(
        name = protoc_gen_es_target,
    )

    gen_connect_es_bin.protoc_gen_connect_es_binary(
        name = protoc_gen_connect_es_target,
    )

    ts_proto_library_rule(
        name = name,
        protoc_gen_es = protoc_gen_es_target,
        protoc_gen_connect_es = protoc_gen_connect_es_target,
        **kwargs
    )

    if not copy_files:
        return
    if not files_to_copy:
        files_to_copy = [s.replace(".proto", "_pb.d.ts") for s in native.glob(["*.proto"])]
        if has_services:
            files_to_copy.extend([s.replace(".proto", "_connect.d.ts") for s in native.glob(["*.proto"])])

    files_target = "_{}.filegroup".format(name)
    dir_target = "_{}.directory".format(name)
    copy_target = "{}.copy".format(name)

    native.filegroup(
        name = files_target,
        srcs = [name],
        output_group = "types",
    )

    copy_to_directory(
        name = dir_target,
        srcs = [files_target],
        root_paths = ["**"],
    )

    write_source_files(
        name = copy_target,
        files = {
            f: make_directory_path("_{}_dirpath".format(f), dir_target, f)
            for f in files_to_copy
        },
    )
