"Define a partial which applies the protoc-gen-es plugin packages to ts_proto_library"

load("@aspect_rules_ts//ts:proto.bzl", _ts_proto_library = "ts_proto_library")
load("@npm//examples/proto_grpc:@bufbuild/protoc-gen-es/package_json.bzl", gen_bin = "bin")
load("@npm//examples/proto_grpc:@bufbuild/protoc-gen-connect-es/package_json.bzl", gen_connect_bin = "bin")

def ts_proto_library(**kwargs):
    _ts_proto_library(
        gen_connect_es_bin = gen_connect_bin,
        gen_es_bin = gen_bin,
        **kwargs
    )
