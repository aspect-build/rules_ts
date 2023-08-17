"Public API for working with Protocol Buffers and gRPC"

# Note: this is not in defs.bzl to avoid an eager load of rules_proto for all users
load("//ts/private:ts_proto_library.bzl", ts_proto_library_rule = "ts_proto_library")

def ts_proto_library(name, gen_es_bin, gen_connect_es_bin = None, **kwargs):
    """
    A macro to generate JavaScript code and TypeScript typings from .proto files.

    Args:
        name: name of resulting ts_proto_library target
        gen_es_bin: the package.json "bin" entry for https://www.npmjs.com/package/@bufbuild/protoc-gen-es
            typically gotten with
                load("@npm//path/to/pkg:@bufbuild/protoc-gen-es/package_json.bzl", gen_bin = "bin")
        gen_connect_es_bin: the package.json "bin" entry for https://www.npmjs.com/package/@bufbuild/protoc-gen-connect-es
            typically gotten with
                load("@npm//path/to/pkg:@bufbuild/protoc-gen-connect-es/package_json.bzl", gen_connect_bin = "bin")
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
