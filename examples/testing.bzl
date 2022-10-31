"helpers for test assertions"

load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@bazel_skylib//lib:types.bzl", "types")
load("@aspect_bazel_lib//lib:params_file.bzl", "params_file")

def assert_outputs(name, actual, expected):
    """Assert that the default outputs of actual are the expected ones

    Args:
        name: name of the resulting diff_test
        actual: string of the label to check the outputs
        expected: expected outputs
    """

    if not types.is_list(expected):
        fail("expected should be a list of strings")
    params_file(
        name = "_actual_" + name,
        data = [actual],
        args = ["$(rootpaths {})".format(actual)],
        out = "_{}_outputs.txt".format(name),
    )
    write_file(
        name = "_expected_ " + name,
        content = expected,
        out = "_expected_{}.txt".format(name),
    )
    diff_test(
        name = name,
        file1 = "_expected_ " + name,
        file2 = "_actual_" + name,
    )
