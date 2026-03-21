load "common.bats"

setup() {
	cd $BATS_FILE_TMPDIR
}

teardown() {
	bazel shutdown
	rm -rf $BATS_FILE_TMPDIR/*
}

@test 'ts_project with a directory in srcs should fail to build' {
	workspace --npm-translate-lock
	tsconfig

	echo 'console.log("hello world")' >source.ts

	cat >>BUILD.bazel <<EOF

copy_directory(
    name = "code_generation",
    src = "inputs",
    out = "generated",
)

EOF

	ts_project -l -s "code_generation"
	run bazel build :foo
	assert_failure
	assert_output -p "fail: srcs of a ts_project should be files not directories"
}
