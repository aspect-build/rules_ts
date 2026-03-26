load "common.bats"

setup() {
	cd $BATS_FILE_TMPDIR
}

teardown() {
	bazel shutdown
	rm -rf $BATS_FILE_TMPDIR/*
}

@test 'ts_project with a directory in srcs should fail to build' {
	workspace
	tsconfig
	mkdir inputs

	ts_project -s ":code_generation"

	cat >>BUILD.bazel <<EOF

load("@aspect_bazel_lib//lib:copy_directory.bzl", "copy_directory")

copy_directory(
    name = "code_generation",
    src = "inputs",
    out = "generated",
)

EOF

	run bazel build :foo
	assert_failure
	assert_output -p "fail: srcs of a ts_project should be files not directories"
}
