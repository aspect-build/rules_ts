"""# Protocol Buffers and gRPC (UNSTABLE)

**UNSTABLE API**: contents of this page are not subject to our usual semver guarantees.
We may make breaking changes in any release.
Please try this API and provide feedback.
We intend to promote it to a stable API in a minor release, possibly as soon as v2.1.0.

`ts_proto_library` uses the Connect library from bufbuild, and supports both Web and Node.js:

- https://connectrpc.com/docs/web/getting-started
- https://connectrpc.com/docs/node/getting-started

This Bazel integration follows the "Local Generation" mechanism described at
https://connectrpc.com/docs/web/generating-code#local-generation,
using the `@connectrpc/protoc-gen-connect-es` and `@bufbuild/protoc-gen-es` packages as plugins to protoc.

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
"""

load("@aspect_bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")
load("@aspect_bazel_lib//lib:directory_path.bzl", "directory_path", "make_directory_path")
load("@aspect_bazel_lib//lib:write_source_files.bzl", "write_source_files")
load("@aspect_rules_js//js:defs.bzl", "js_binary")
load("//ts/private:ts_proto_library.bzl", ts_proto_library_rule = "ts_proto_library")

def ts_proto_library(name, node_modules, has_services = True, copy_files = True, files_to_copy = None, **kwargs):
    """
    A macro to generate JavaScript code and TypeScript typings from .proto files.

    Args:
        name: name of resulting ts_proto_library target
        node_modules: Label pointing to the linked node_modules target where @bufbuild/protoc-gen-es is linked, e.g. //:node_modules.
            Since the generated code depends on @bufbuild/protobuf, this package must also be linked.
            If `has_services = True` then @bufbuild/proto-gen-connect-es should be linked as well.
        has_services: whether the proto file contains a service, and therefore *_connect.{js,d.ts} should be written.
        copy_files: whether to copy the resulting .d.ts files back to the source tree, for the editor to locate them.
        files_to_copy: which files from the protoc output to copy. By default, scans for *.proto in the current package
            and replaces with the typical output filenames.
        **kwargs: additional named arguments to the ts_proto_library rule
    """
    if type(node_modules) != "string":
        fail("node_modules should be a label, not a " + type(node_modules))
    protoc_gen_es_target = "_{}.gen_es".format(name)
    protoc_gen_es_entry = protoc_gen_es_target + "__entry_point"

    # Reach into the node_modules to find the entry points
    directory_path(
        name = protoc_gen_es_entry,
        tags = ["manual"],
        directory = node_modules + "/@bufbuild/protoc-gen-es/dir",
        path = "bin/protoc-gen-es",
    )
    js_binary(
        name = protoc_gen_es_target,
        data = [node_modules + "/@bufbuild/protoc-gen-es"],
        entry_point = protoc_gen_es_entry,
    )

    protoc_gen_connect_es_target = None
    if has_services:
        protoc_gen_connect_es_target = "_{}.gen_connect_es".format(name)
        protoc_gen_connect_es_entry = protoc_gen_connect_es_target + "__entry_point"
        directory_path(
            name = protoc_gen_connect_es_entry,
            tags = ["manual"],
            directory = node_modules + "/@connectrpc/protoc-gen-connect-es/dir",
            path = "bin/protoc-gen-connect-es",
        )
        js_binary(
            name = protoc_gen_connect_es_target,
            data = [node_modules + "/@connectrpc/protoc-gen-connect-es"],
            entry_point = protoc_gen_connect_es_entry,
        )

    ts_proto_library_rule(
        name = name,
        protoc_gen_es = protoc_gen_es_target,
        protoc_gen_connect_es = protoc_gen_connect_es_target,
        # The codegen always has a runtime dependency on the protobuf runtime
        deps = kwargs.pop("deps", []) + [node_modules + "/@bufbuild/protobuf"],
        has_services = has_services,
        **kwargs
    )

    if not copy_files:
        return
    if not files_to_copy:
        proto_srcs = native.glob(["**/*.proto"])
        files_to_copy = [s.replace(".proto", "_pb.d.ts") for s in proto_srcs]
        if has_services:
            files_to_copy.extend([s.replace(".proto", "_connect.d.ts") for s in proto_srcs])

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
