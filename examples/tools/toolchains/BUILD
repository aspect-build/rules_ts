load("@aspect_rules_ts//ts:proto.bzl", "ts_protoc_plugin_toolchain")
load("@npm//tools:@bufbuild/protoc-gen-es/package_json.bzl", gen_es = "bin")
load("@npm//tools:@connectrpc/protoc-gen-connect-query/package_json.bzl", gen_connect_query = "bin")

gen_es.protoc_gen_es_binary(
    name = "protoc_gen_es",
)

# FIXME: wire this up to another toolchain_type symbol?
gen_connect_query.protoc_gen_connect_query_binary(
    name = "protoc_gen_connect_query",
)

ts_protoc_plugin_toolchain(
    name = "ts_protoc_plugin",
    command_line = "--es_opt=keep_empty_files=true --es_opt=target=js+dts --es_opt=import_extension=js",
    protoc_plugin = "protoc_gen_es",
    # NB: this must be a parent folder of any package that use the toolchain
    # Otherwise typescript won't resolve a dep from the generated code in that package to the @bufbuild/protobuf package
    runtime = "//:node_modules/@bufbuild/protobuf",
)
