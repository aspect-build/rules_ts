load "common.bats"

setup() {
	cd $BATS_FILE_TMPDIR
}

teardown() {
	bazel shutdown
	rm -rf $BATS_FILE_TMPDIR/*
}

# Regression tests for https://github.com/aspect-build/rules_ts/issues/935
#
# When a ts_project has `declaration = False`, tsc emits only .js files (no
# .d.ts). The per-target `typecheck` output group is populated either from a
# dedicated --noEmit action (when tsc emits nothing) or from the emitted .d.ts
# files. With `declaration = False` neither happens, so `typecheck_outs` ends
# up empty and the `transitive_typecheck` output group has nothing to pull on
# -- building it runs no tsc action and silently skips type-checking.
#
# NOTE: these tests build the `transitive_typecheck` *output group* directly
# rather than the generated `_transitive_typecheck` filegroup target. Building
# the filegroup also materializes the target's default outputs and runfiles
# (which, for a plain tsc target, happen to run the emitting+type-checking
# action) and would therefore mask the bug. `--output_groups` isolates the
# output group under test.

@test 'transitive_typecheck output group type-checks a declaration=False target' {
	workspace

	# declaration defaults to false in the tsconfig + ts_project helpers.
	tsconfig

	echo 'export const a: string = 1' >source.ts
	ts_project -s "source.ts"

	run bazel build --output_groups=transitive_typecheck :foo
	assert_failure
	assert_output -p "source.ts(1,14): error TS2322"
}

@test 'transitive_typecheck output group type-checks declaration=False deps' {
	workspace
	tsconfig

	# Leaf package "b" with declaration = False and a type error.
	mkdir -p b
	tsconfig --path b
	echo 'export const b: string = 1' >b/b.ts
	ts_project --path b --name b -s "b.ts"

	# Root package depends on //b:b, also declaration = False, and is itself
	# error-free.
	echo 'export const a: number = 1' >source.ts
	ts_project --name a -s "source.ts" -d "//b:b"

	run bazel build --output_groups=transitive_typecheck :a
	assert_failure
	assert_output -p "b.ts(1,14): error TS2322"
}
