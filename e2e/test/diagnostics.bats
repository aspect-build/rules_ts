load "common.bats"

setup() {
	cd $BATS_FILE_TMPDIR
}

teardown() {
	bazel shutdown
	rm -rf $BATS_FILE_TMPDIR/*
}

@test 'build a target that will never succeed' {
	workspace
	ts_project --src "source.ts"
	tsconfig
	echo 'const t: string = 1' >source.ts
	run bazel build :foo
	assert_failure
	assert_output -p "source.ts(1,7): error TS2322: Type 'number' is not assignable to type 'string'" "FAILED: Build did NOT complete successfully"
}

@test 'should stop reporting diagnostics' {
	workspace
	ts_project --src "source.ts"
	tsconfig
	echo 'const t: string;' >source.ts
	run bazel build :foo
	assert_failure
	assert_output -p "source.ts(1,7): error TS1155: 'const' declarations must be initialized."

	echo 'const t: string = "";' >source.ts
	run bazel build :foo
	assert_success
	refute_output -p "error"
}

@test 'should stop reporting diagnostics for removed srcs' {
	workspace
	ts_project --src "source.ts" --src "to_be_removed.ts"
	tsconfig
	echo 'let t: string;' >source.ts
	echo 'const t2: string;' >to_be_removed.ts

	run bazel build :foo
	assert_failure
	assert_output -p "to_be_removed.ts(1,7): error TS1155: 'const' declarations must be initialized."

	rm to_be_removed.ts
	ts_project --src "source.ts"
	run bazel build :foo
	assert_success
	refute_output -p "error"
}

@test 'tsconfig changes should emit new errors' {
	workspace
	ts_project --src "source.ts"
	tsconfig
	echo 'export function t(a) { return typeof a != "string" }' >source.ts

	run bazel build :foo
	assert_success
	refute_output -p "error"

	tsconfig --no-implicit-any
	run bazel build :foo
	assert_failure
	assert_output -p "source.ts(1,19): error TS7006: Parameter 'a' implicitly has an 'any' type."
}
