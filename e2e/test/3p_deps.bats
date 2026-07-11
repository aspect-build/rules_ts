load "common.bats"

setup() {
	cd $BATS_FILE_TMPDIR
}

teardown() {
	bazel shutdown
	rm -rf $BATS_FILE_TMPDIR/*
}

@test 'should handle 3p dependency upgrade and downgrade gracefully' {
	run pnpm add @nestjs/core@9.2.0 @nestjs/common@9.2.0 rxjs@7.1.0 @types/node@18.19.130 --lockfile-only

	workspace --npm-translate-lock
	tsconfig

	echo 'export * as core from "@nestjs/core"' >source.ts
	echo 'console.log("test")' >>source.ts

	ts_project -l -s "source.ts" -d ":node_modules/@types/node" -d ":node_modules/@nestjs/core" -d ":node_modules/@nestjs/common"
	run bazel build :foo
	assert_success
	refute_output -p "error" "@nestjs/core" "@types/node"

	# upgrade: @nestjs/core from 9.2.0 to 9.2.1
	# dowgrade: @types/node from 18.19.130 to 18.11.9, which fails libcheck under typescript 5.x
	run pnpm add @nestjs/core@9.2.1 @types/node@18.11.9 --lockfile-only

	run bazel build :foo
	assert_failure
	assert_output -p "error TS2386: Overload signatures must all be optional or required."

	# dowgrade: @nestjs/core from 9.2.1 to 9.2.0
	# upgrade: @types/node from 18.11.9 to 18.19.130
	run pnpm add @nestjs/core@9.2.0 @types/node@18.19.130 --lockfile-only

	run bazel build :foo
	assert_success
	refute_output -p "error" "@nestjs/core" "@types/node"
}
