<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for working with Protocol Buffers and gRPC

<a id="ts_proto_library"></a>

## ts_proto_library

<pre>
ts_proto_library(<a href="#ts_proto_library-name">name</a>, <a href="#ts_proto_library-gen_es_bin">gen_es_bin</a>, <a href="#ts_proto_library-gen_connect_es_bin">gen_connect_es_bin</a>, <a href="#ts_proto_library-kwargs">kwargs</a>)
</pre>

    A macro to generate JavaScript code and TypeScript typings from .proto files.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="ts_proto_library-name"></a>name |  name of resulting ts_proto_library target   |  none |
| <a id="ts_proto_library-gen_es_bin"></a>gen_es_bin |  the package.json "bin" entry for https://www.npmjs.com/package/@bufbuild/protoc-gen-es typically gotten with     load("@npm//path/to/pkg:@bufbuild/protoc-gen-es/package_json.bzl", gen_bin = "bin")   |  none |
| <a id="ts_proto_library-gen_connect_es_bin"></a>gen_connect_es_bin |  the package.json "bin" entry for https://www.npmjs.com/package/@bufbuild/protoc-gen-connect-es typically gotten with     load("@npm//path/to/pkg:@bufbuild/protoc-gen-connect-es/package_json.bzl", gen_connect_bin = "bin")   |  <code>None</code> |
| <a id="ts_proto_library-kwargs"></a>kwargs |  additional named arguments to the ts_proto_library rule   |  none |


