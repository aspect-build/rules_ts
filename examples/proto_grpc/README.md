Design

-   Only support .js/.d.ts emit pair, as we don't wire up with a ts_project transpiler right now.
    TODO: maybe (ab)use output_files=single to mean .ts and output_files=multiple to mean .js/.d.ts pair?
    https://github.com/protocolbuffers/protobuf/blob/main/bazel/private/proto_lang_toolchain_rule.bzl#L105-L108
