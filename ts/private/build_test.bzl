"""Fork of @bazel_skylib//rules:build_test.bzl

Workaround for https://github.com/bazelbuild/bazel-skylib/issues/480
"""

_DOC = """\
build_test is a trivial test that always passes.

It is used to force Bazel to build some of its dependencies, in the case where
`--build_tests_only` would have otherwise caused those to be skipped.
"""

def _build_test_impl(ctx):
    # See https://github.com/bazelbuild/bazel-skylib/blob/1.8.0/rules/build_test.bzl#L19-L34

    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    extension = ".bat" if is_windows else ".sh"
    content = "exit 0" if is_windows else "#!/usr/bin/env bash\nexit 0"
    executable = ctx.actions.declare_file(ctx.label.name + extension)
    ctx.actions.write(
        output = executable,
        is_executable = True,
        content = content,
    )

    return DefaultInfo(
        files = depset([executable]),
        executable = executable,
        # The critical fix, so that the test inputs include the default outputs of the targets to check
        runfiles = ctx.runfiles(files = ctx.files.targets),
    )

_build_test = rule(
    doc = _DOC,
    implementation = _build_test_impl,
    attrs = {
        "targets": attr.label_list(allow_files = True),
        "_windows_constraint": attr.label(default = "@platforms//os:windows"),
    },
    test = True,
)

def build_test(name, **kwargs):
    _build_test(
        name = name,
        **kwargs
    )
