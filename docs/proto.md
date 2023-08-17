<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Protocol Buffers and gRPC

Note this is not included in `defs.bzl` to avoid eager loads of rules_proto for all rules_ts users.


<a id="ts_proto_library"></a>

## ts_proto_library

<pre>
ts_proto_library(<a href="#ts_proto_library-name">name</a>, <a href="#ts_proto_library-gen_es_bin">gen_es_bin</a>, <a href="#ts_proto_library-gen_connect_es_bin">gen_connect_es_bin</a>, <a href="#ts_proto_library-has_services">has_services</a>, <a href="#ts_proto_library-copy_files">copy_files</a>, <a href="#ts_proto_library-files_to_copy">files_to_copy</a>,
                 <a href="#ts_proto_library-kwargs">kwargs</a>)
</pre>

    A macro to generate JavaScript code and TypeScript typings from .proto files.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="ts_proto_library-name"></a>name |  name of resulting ts_proto_library target   |  none |
| <a id="ts_proto_library-gen_es_bin"></a>gen_es_bin |  the package.json "bin" entry for https://www.npmjs.com/package/@bufbuild/protoc-gen-es typically loaded with <code>load("@npm//path/to/pkg:@bufbuild/protoc-gen-es/package_json.bzl", gen_bin = "bin")</code>   |  none |
| <a id="ts_proto_library-gen_connect_es_bin"></a>gen_connect_es_bin |  the package.json "bin" entry for https://www.npmjs.com/package/@bufbuild/protoc-gen-connect-es typically loaded with <code>load("@npm//path/to/pkg:@bufbuild/protoc-gen-connect-es/package_json.bzl", gen_connect_bin = "bin")</code>   |  <code>None</code> |
| <a id="ts_proto_library-has_services"></a>has_services |  whether the proto file contains a service, and therefore *_connect.{js,d.ts} should be written.   |  <code>True</code> |
| <a id="ts_proto_library-copy_files"></a>copy_files |  whether to copy the resulting .d.ts files back to the source tree, for the editor to locate them.   |  <code>True</code> |
| <a id="ts_proto_library-files_to_copy"></a>files_to_copy |  which files from the protoc output to copy. By default, scans for *.proto in the current package and replaces with the typical output filenames.   |  <code>None</code> |
| <a id="ts_proto_library-kwargs"></a>kwargs |  additional named arguments to the ts_proto_library rule   |  none |


