load "common.bats"

setup() {
	cd $BATS_FILE_TMPDIR
}

teardown() {
	bazel shutdown
	rm -rf $BATS_FILE_TMPDIR/*
}

@test 'When tsc is only used for type-checking with a type-error, should pass when [name]_typecheck target not built' {
	workspace

	echo "export const a: string = 1;" >./source.ts
	tsconfig --declaration
	ts_project --transpiler-mock --declaration --src "source.ts"

	run bazel build :foo
	assert_success
	run cat bazel-bin/source.js
	assert_success
	# Mock transpiler just copies source input to output
	assert_output -p 'export const a: string = 1;'
}

@test 'When tsc is only used for type-checking with a type-error, should fail when [name]_typecheck target built' {
	workspace

	echo "export const a: string = 1;" >./source.ts
	tsconfig --no-emit
	ts_project --transpiler-mock --no-emit --src "source.ts"

	run bazel build :foo_typecheck
	assert_failure
	assert_output -p "error TS2322: Type 'number' is not assignable to type 'string'"
}

@test 'When rootDir in tsconfig does not match non-empty root_dir attr, should fail validation' {
	workspace

	echo "export const a = 1;" >./source.ts
	tsconfig --root-dir "src"
	ts_project --root_dir "other-src" --src "source.ts"

	run bazel build :foo
	assert_failure
	assert_output -p 'root_dir'
	assert_output -p 'rootDir'
}

@test 'When rootDir in tsconfig matches root_dir attr, should succeed' {
	workspace

	mkdir src
	echo "export const a = 1;" >./src/source.ts
	tsconfig --root-dir "src" --exclude-empty
	ts_project --root_dir "src" --src "src/source.ts"

	run bazel build :foo
	assert_success
}

@test 'When outDir in tsconfig does not match non-empty out_dir attr, should fail validation' {
	workspace

	echo "export const a = 1;" >./source.ts
	tsconfig --out-dir "dist"
	ts_project --out_dir "other-dist" --src "source.ts"

	run bazel build :foo
	assert_failure
	assert_output -p 'out_dir'
	assert_output -p 'outDir'
}

@test 'When outDir in tsconfig matches out_dir attr, should succeed' {
	workspace

	echo "export const a = 1;" >./source.ts
	tsconfig --out-dir "dist"
	ts_project --out_dir "dist" --src "source.ts"

	run bazel build :foo
	assert_success
}

@test 'When declarationDir in tsconfig does not match declaration_dir attr, should fail validation' {
	workspace

	echo "export const a = 1;" >./source.ts
	tsconfig --declaration --declaration-dir "types"
	ts_project --declaration --src "source.ts"

	run bazel build :foo
	assert_failure
	assert_output -p 'declaration_dir'
	assert_output -p 'declarationDir'
}

@test 'When declarationDir in tsconfig does not match non-empty declaration_dir attr, should fail validation' {
	workspace

	echo "export const a = 1;" >./source.ts
	tsconfig --declaration --declaration-dir "types"
	ts_project --declaration --declaration-dir "gen-types" --src "source.ts"

	run bazel build :foo
	assert_failure
	assert_output -p 'declaration_dir'
	assert_output -p 'declarationDir'
}

@test 'When declarationDir in tsconfig matches declaration_dir attr, should succeed' {
	workspace

	echo "export const a = 1;" >./source.ts
	tsconfig --declaration --declaration-dir "types"
	ts_project --declaration --declaration-dir "types" --src "source.ts"

	run bazel build :foo
	assert_success
}
