"UnitTest for ts_proto_library"

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//ts:proto.bzl", "ts_proto_library")

def ts_proto_library_test_suite(name):
    """Test suite including all tests and data.

    Args:
        name: The name of the test suite.
    """

    ts_proto_library(
        name = "ts_proto_library_with_dep",
        # The //examples package is the root pnpm package for the repo, so we
        # borrow from the proto/grpc example to provide the required
        # ts_proto_library npm dependencies.
        node_modules = "//examples/proto_grpc:node_modules",
        proto = "//ts/test/ts_proto_library:foo_proto",
        proto_srcs = ["//ts/test/ts_proto_library:foo.proto"],
        # This is disabled to avoid checking in the output files, which are
        # implicitly inputs for the copy_file tests.
        copy_files = False,
        tags = ["manual"],
    )

    build_test(
        name = "ts_proto_library_with_dep_test",
        targets = [":ts_proto_library_with_dep"],
    )
