load "common.bats"

# These tests demonstrate that a ts_project compilation is only hermetic
# because of Bazel's sandbox. When the tsconfig pins neither `files` nor
# `include`, tsc globs every .ts under its --rootDir (the bazel-bin package
# directory). The sandbox stages only the target's declared inputs, so tsc
# sees just the declared srcs. Drop the sandbox (--strategy=TsProject=local)
# and any .ts another target generated into that same bin directory leaks into
# the compilation. See the note in //ts/test:ts_config_test.bzl.

setup() {
	cd $BATS_FILE_TMPDIR
}

teardown() {
	bazel shutdown
	rm -rf $BATS_FILE_TMPDIR/*
}

# A workspace whose :foo compiles a single declared source with an unpinned
# tsconfig, alongside a sibling genrule that emits an undeclared leaked.ts
# (with a type error) into the same bazel-bin package directory.
#
# Takes a unique marker baked into source.ts. The two tests below differ only
# in --strategy, which is NOT part of the tsc action's cache key, so without a
# distinct source per test the sandboxed run's cached success would be served
# to the local run (both tests share an output base).
function leaky_workspace() {
	local marker="$1"
	workspace
	tsconfig
	echo "export const t: string = \"ok\"; // $marker" >source.ts
	cat >BUILD.bazel <<-'EOF'
		load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

		ts_project(
		    name = "foo",
		    srcs = ["source.ts"],
		    tsconfig = "tsconfig.json",
		)

		# Emits an undeclared sibling into bazel-bin/<pkg>/leaked.ts. It is not a
		# src of :foo, but tsc's unpinned glob over its --rootDir would compile it.
		genrule(
		    name = "gen_leaked",
		    outs = ["leaked.ts"],
		    cmd = "echo 'export const leaked: string = 123;' > $@",
		)
	EOF
	# Populate bazel-bin with the undeclared sibling so it is present on disk
	# when :foo is compiled below.
	run bazel build :gen_leaked
	assert_success
}

@test 'tsc ignores an undeclared sibling under the sandbox' {
	leaky_workspace "sandboxed"

	run bazel build :foo --strategy=TsProject=sandboxed
	assert_success
	refute_output -p "leaked.ts"
}

@test 'tsc compiles an undeclared sibling without the sandbox' {
	leaky_workspace "local"

	run bazel build :foo --strategy=TsProject=local
	assert_failure
	assert_output -p "leaked.ts"
	assert_output -p "error TS2322"
}
