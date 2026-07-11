load "common.bats"

setup() {
	cd $BATS_FILE_TMPDIR
}

teardown() {
	bazel shutdown
	rm -rf $BATS_FILE_TMPDIR/*
}

@test 'should report errors' {
	workspace
	tsconfig

	echo 'export type test = string' >lib.ts
	echo 'import {test} from "./lib"; export {test}' >source.ts
	ts_project -s "source.ts" -s "lib.ts"

	run bazel build :foo
	assert_success
	refute_output -p "error"

	tsconfig --isolated-modules
	run bazel build :foo
	assert_failure
	assert_output -p "source.ts(1,37): error TS1205: Re-exporting a type when 'isolatedModules' is enabled requires using 'export type'."
}

@test 'should report errors for 3p deps' {
	run pnpm add @types/node@18.19.130 --lockfile-only

	workspace --npm-translate-lock
	tsconfig --extended-diagnostics

	echo 'import {BigIntStats} from "node:fs"; export {BigIntStats}' >source.ts
	ts_project -l -s "source.ts" -d ":node_modules/@types/node"

	run bazel build :foo
	assert_success
	refute_output -p "error"

	tsconfig --isolated-modules --extended-diagnostics
	echo " " >>source.ts # TODO: figure out why the case above works but not this one.
	run bazel build :foo

	assert_failure
	assert_output -p "source.ts(1,46): error TS1205: Re-exporting a type when 'isolatedModules' is enabled requires using 'export type'."

}
