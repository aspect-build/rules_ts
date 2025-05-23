<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Protocol Buffers and gRPC (UNSTABLE)

**UNSTABLE API**: contents of this page are not subject to our usual semver guarantees.
We may make breaking changes in any release.
Please try this API and provide feedback.
We intend to promote it to a stable API in a minor release, possibly as soon as v2.1.0.

`ts_proto_library` uses the Connect library from bufbuild, and supports both Web and Node.js:

- https://connectrpc.com/docs/web/getting-started
- https://connectrpc.com/docs/node/getting-started

This Bazel integration follows the "Local Generation" mechanism described at
https://connectrpc.com/docs/web/generating-code#local-generation,
using packages such as `@bufbuild/protoc-gen-es` and `@connectrpc/protoc-gen-connect-query`
as plugins to protoc.

The [aspect configure](https://docs.aspect.build/cli/commands/aspect_configure) command
auto-generates `ts_proto_library` rules as of the 5.7.2 release.
It's also possible to compile this library into your Gazelle binary.

Note: this API surface is not included in `defs.bzl` to avoid eager loads of rules_proto for all rules_ts users.

Installation
------------

If you install rules_ts in `WORKSPACE`, you'll need to install the deps of rules_proto, like this:

```
load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies")

rules_proto_dependencies()
```

If you use bzlmod/`MODULE.bazel` then no extra install is required.

Future work
-----------

- Allow users to choose other plugins. We intend to wait until http://github.com/bazelbuild/rules_proto supports protoc plugins.
- Allow users to control the output format. Currently it is hard-coded to `js+dts`, and the JS output uses ES Modules.

<a id="ts_proto_library"></a>

## ts_proto_library

<pre>
load("@aspect_rules_ts//ts:proto.bzl", "ts_proto_library")

ts_proto_library(<a href="#ts_proto_library-name">name</a>, <a href="#ts_proto_library-node_modules">node_modules</a>, <a href="#ts_proto_library-proto">proto</a>, <a href="#ts_proto_library-protoc_gen_options">protoc_gen_options</a>, <a href="#ts_proto_library-gen_connect_es">gen_connect_es</a>, <a href="#ts_proto_library-gen_connect_query">gen_connect_query</a>,
                 <a href="#ts_proto_library-gen_connect_query_service_mapping">gen_connect_query_service_mapping</a>, <a href="#ts_proto_library-copy_files">copy_files</a>, <a href="#ts_proto_library-proto_srcs">proto_srcs</a>, <a href="#ts_proto_library-files_to_copy">files_to_copy</a>, <a href="#ts_proto_library-kwargs">kwargs</a>)
</pre>

A macro to generate JavaScript code and TypeScript typings from .proto files.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="ts_proto_library-name"></a>name |  name of resulting ts_proto_library target   |  none |
| <a id="ts_proto_library-node_modules"></a>node_modules |  Label pointing to the linked node_modules target where @bufbuild/protoc-gen-es is linked, e.g. //:node_modules. Since the generated code depends on @bufbuild/protobuf, this package must also be linked. If `gen_connect_es = True` then @bufbuild/proto-gen-connect-es should be linked as well. If `gen_connect_query = True` then @bufbuild/proto-gen-connect-query should be linked as well.   |  none |
| <a id="ts_proto_library-proto"></a>proto |  the `proto_library` target that contains the .proto files to generate code for.   |  none |
| <a id="ts_proto_library-protoc_gen_options"></a>protoc_gen_options |  dict of protoc_gen_es options. See https://github.com/bufbuild/protobuf-es/tree/main/packages/protoc-gen-es#plugin-options   |  `{}` |
| <a id="ts_proto_library-gen_connect_es"></a>gen_connect_es |  [deprecated] whether protoc_gen_connect_es should generate grpc services, and therefore `*_connect.{js,d.ts}` should be written.   |  `False` |
| <a id="ts_proto_library-gen_connect_query"></a>gen_connect_query |  whether protoc_gen_connect_query should generate [TanStack Query](https://tanstack.com/query) clients, and therefore `*_connectquery.{js,d.ts}` should be written.   |  `False` |
| <a id="ts_proto_library-gen_connect_query_service_mapping"></a>gen_connect_query_service_mapping |  mapping from source proto file to the named RPC services that file contains. Needed to predict which files will be generated by gen_connect_query. See https://github.com/connectrpc/connect-query-es/tree/main/examples/react/basic/src/gen<br><br>For example, given `a.proto` which contains a service `Foo` and `b.proto` that contains a service `Bar`, the mapping would be `{"a.proto": ["Foo"], "b.proto": ["Bar"]}`   |  `{}` |
| <a id="ts_proto_library-copy_files"></a>copy_files |  whether to copy the resulting `.d.ts` files back to the source tree, for the editor to locate them.   |  `True` |
| <a id="ts_proto_library-proto_srcs"></a>proto_srcs |  the .proto files that are being generated. Repeats the `srcs` of the `proto_library` target. This is used only to determine a default for `files_to_copy`.   |  `None` |
| <a id="ts_proto_library-files_to_copy"></a>files_to_copy |  which files from the protoc output to copy. By default, performs a replacement on `proto_srcs` with the typical output filenames.   |  `None` |
| <a id="ts_proto_library-kwargs"></a>kwargs |  additional named arguments to the ts_proto_library rule   |  none |


