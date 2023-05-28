# rules_js rules_proto_grpc example

This example shows how to define a custom proto compilation rule by parameterizing
the @rules_proto_grpc rules with compiler plugins imported from @bufbuild/* npm
packages.

The main BUILD file contains some documentation, and gives a general overview of
what does what. For the build rule definiton and the actual meat of the example,
see the `tools/` directory. For examples of actually using the compiled protos,
see the client and server `.ts` files and the associated test.

The easiest way to build and run everything is to run the test suite as follows:

```bash
bazel run //:test
```