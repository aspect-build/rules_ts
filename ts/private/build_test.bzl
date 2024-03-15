"""Fork of @bazel_skylib//rules:build_test.bzl

Workaround for https://github.com/bazelbuild/bazel-skylib/issues/480
"""

_DOC = """\
build_test is a trivial test that always passes.

It is used to force Bazel to build some of its dependencies, in the case where
`--build_tests_only` would have otherwise caused those to be skipped.
"""

def _build_test_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = executable,
        is_executable = True,
        content = "#!/usr/bin/env bash\nexit 0",
    )

    return DefaultInfo(
        files = depset([executable]),
        executable = executable,
        # The critical fix, so that the test inputs include the default outputs of the targets to check
        runfiles = ctx.runfiles(files = ctx.files.targets),
    )

build_test = rule(
    doc = _DOC,
    implementation = _build_test_impl,
    attrs = {
        "targets": attr.label_list(allow_files = True),
    },
    test = True,
)
