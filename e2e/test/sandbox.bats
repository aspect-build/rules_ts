load "common.bats"

# These tests demonstrate the ways a ts_project compilation stays correct only
# because of Bazel's sandbox. Each scenario plants an *undeclared* file into the
# bazel-bin package directory (via a sibling target) that tsc or node would pick
# up if it were visible. With the sandbox only the target's declared inputs are
# staged, so the leak is invisible and the build succeeds. Drop the sandbox
# (--strategy=TsProject=local) and the leak takes effect, breaking the build.
#
# Each scenario builds the SAME setup in two sibling packages: `<s>_ok` compiled
# under --strategy=TsProject=sandboxed (must succeed) and `<s>_no` compiled under
# --strategy=TsProject=local (must fail). Two separate packages are required:
#   - --strategy is NOT part of the tsc action cache key, so building one package
#     under both strategies would serve the sandboxed success to the local run.
#   - Undeclared files leaked into bazel-bin persist across builds in the shared
#     output base, so distinct package dirs keep scenarios from polluting each
#     other's unpinned globs.
# See the note in //ts/test:ts_config_test.bzl for the real-world motivation.

setup() {
	cd $BATS_FILE_TMPDIR
}

teardown() {
	bazel shutdown
	rm -rf $BATS_FILE_TMPDIR/*
}

# --- Scenario 1: undeclared sibling .ts globbed by an unpinned tsconfig -------
# tsconfig pins neither `files` nor `include`, so tsc globs every .ts under its
# --rootDir. A sibling genrule emits an undeclared leaked.ts (type error) there.
function mk_sibling() {
	local dir="$1"
	mkdir -p "$dir"
	echo '{"compilerOptions": {}}' >"$dir/tsconfig.json"
	echo 'export const t: string = "ok";' >"$dir/source.ts"
	cat >"$dir/BUILD.bazel" <<-'EOF'
		load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

		ts_project(
		    name = "foo",
		    srcs = ["source.ts"],
		    tsconfig = "tsconfig.json",
		)

		genrule(
		    name = "leak",
		    outs = ["leaked.ts"],
		    cmd = "echo 'export const leaked: string = 123;' > $@",
		)
	EOF
	run bazel build "//$dir:leak"
	assert_success
}

@test 'sibling .ts: sandbox ignores it, local compiles it (TS2322)' {
	workspace
	mk_sibling "sib_ok"
	mk_sibling "sib_no"

	run bazel build //sib_ok:foo --strategy=TsProject=sandboxed
	assert_success

	run bazel build //sib_no:foo --strategy=TsProject=local
	assert_failure
	assert_output -p "leaked.ts"
	assert_output -p "error TS2322"
}

# --- Scenario 2: undeclared package.json flips the module system --------------
# Under moduleResolution "nodenext", tsc classifies each .ts as CommonJS or ESM
# by the nearest package.json "type". With none declared, source.ts is CommonJS
# and `export =` is legal; a leaked {"type":"module"} reclassifies it as ESM,
# where `export =` is TS1203. (The runtime version of this leak manifests as
# `require is not defined in ES module scope`.)
function mk_module_flip() {
	local dir="$1"
	mkdir -p "$dir"
	echo '{"compilerOptions": {"module": "nodenext", "moduleResolution": "nodenext", "target": "ES2020"}}' >"$dir/tsconfig.json"
	echo 'const v = 1; export = v;' >"$dir/source.ts"
	cat >"$dir/BUILD.bazel" <<-'EOF'
		load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

		ts_project(
		    name = "foo",
		    srcs = ["source.ts"],
		    tsconfig = "tsconfig.json",
		)

		genrule(
		    name = "leak",
		    outs = ["package.json"],
		    cmd = "echo '{\"type\": \"module\"}' > $@",
		)
	EOF
	run bazel build "//$dir:leak"
	assert_success
}

@test 'package.json: sandbox ignores it, local flips module system (TS1203)' {
	workspace
	mk_module_flip "mod_ok"
	mk_module_flip "mod_no"

	run bazel build //mod_ok:foo --strategy=TsProject=sandboxed
	assert_success

	run bazel build //mod_no:foo --strategy=TsProject=local
	assert_failure
	assert_output -p "TS1203"
}

# --- Scenario 3: undeclared @types package auto-included via typeRoots ---------
# tsc auto-includes every package under typeRoots. A sibling emits an undeclared
# types package whose declaration references an unknown type; without the sandbox
# tsc includes it and reports TS2304.
function mk_typeroots() {
	local dir="$1"
	mkdir -p "$dir"
	echo '{"compilerOptions": {"typeRoots": ["./typ"]}}' >"$dir/tsconfig.json"
	echo 'export const x = 1;' >"$dir/source.ts"
	cat >"$dir/BUILD.bazel" <<-'EOF'
		load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

		ts_project(
		    name = "foo",
		    srcs = ["source.ts"],
		    tsconfig = "tsconfig.json",
		)

		genrule(
		    name = "leak",
		    outs = ["typ/bad/index.d.ts", "typ/bad/package.json"],
		    cmd = "echo 'declare const bad: Nope;' > $(location typ/bad/index.d.ts) && echo '{\"types\": \"index.d.ts\"}' > $(location typ/bad/package.json)",
		)
	EOF
	run bazel build "//$dir:leak"
	assert_success
}

@test 'typeRoots: sandbox ignores leaked @types, local includes it (TS2304)' {
	workspace
	mk_typeroots "typ_ok"
	mk_typeroots "typ_no"

	run bazel build //typ_ok:foo --strategy=TsProject=sandboxed
	assert_success

	run bazel build //typ_no:foo --strategy=TsProject=local
	assert_failure
	assert_output -p "TS2304"
}

# --- Scenario 4: leaked generated output collides with tsc's emit -------------
# :foo emits declarations. A sibling emits both orphan.ts (valid) and a
# read-only orphan.d.ts. Without the sandbox tsc globs orphan.ts and tries to
# emit orphan.d.ts over the read-only leaked file, failing to write (TS5033).
function mk_output_collision() {
	local dir="$1"
	mkdir -p "$dir"
	echo '{"compilerOptions": {"declaration": true}}' >"$dir/tsconfig.json"
	echo 'export const x = 1;' >"$dir/source.ts"
	cat >"$dir/BUILD.bazel" <<-'EOF'
		load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

		ts_project(
		    name = "foo",
		    srcs = ["source.ts"],
		    declaration = True,
		    tsconfig = "tsconfig.json",
		)

		genrule(name = "leak_ts", outs = ["orphan.ts"], cmd = "echo 'export const o = 1;' > $@")
		genrule(name = "leak_dts", outs = ["orphan.d.ts"], cmd = "echo 'export declare const o: number;' > $@")
	EOF
	run bazel build "//$dir:leak_ts" "//$dir:leak_dts"
	assert_success
}

@test 'output collision: sandbox ignores orphan, local cannot emit over it (TS5033)' {
	workspace
	mk_output_collision "col_ok"
	mk_output_collision "col_no"

	run bazel build //col_ok:foo --strategy=TsProject=sandboxed
	assert_success

	run bazel build //col_no:foo --strategy=TsProject=local
	assert_failure
	assert_output -p "TS5033"
}

# --- Scenario 5: leaked ambient .d.ts redeclares a global ---------------------
# An unpinned glob also picks up .d.ts files. A sibling emits an ambient .d.ts
# that redeclares a global also declared in source.ts; without the sandbox tsc
# sees both and reports a redeclaration (TS2451).
function mk_ambient_dts() {
	local dir="$1"
	mkdir -p "$dir"
	echo '{"compilerOptions": {}}' >"$dir/tsconfig.json"
	# No import/export: source.ts is a script, so `SHARED` is a global that
	# collides with the leaked global .d.ts. (An `export` would make it a module
	# and module-scope the declaration, hiding the conflict.)
	echo 'declare const SHARED: number; const use1 = SHARED;' >"$dir/source.ts"
	cat >"$dir/BUILD.bazel" <<-'EOF'
		load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

		ts_project(
		    name = "foo",
		    srcs = ["source.ts"],
		    tsconfig = "tsconfig.json",
		)

		genrule(
		    name = "leak",
		    outs = ["extra.d.ts"],
		    cmd = "echo 'declare const SHARED: string;' > $@",
		)
	EOF
	run bazel build "//$dir:leak"
	assert_success
}

@test 'ambient .d.ts: sandbox ignores it, local sees a redeclared global (TS2451)' {
	workspace
	mk_ambient_dts "amb_ok"
	mk_ambient_dts "amb_no"

	run bazel build //amb_ok:foo --strategy=TsProject=sandboxed
	assert_success

	run bazel build //amb_no:foo --strategy=TsProject=local
	assert_failure
	assert_output -p "TS2451"
}

# --- Scenario 6: an extended tsconfig's `include` widens the glob -------------
# tsconfig.json pins `files` to just source.ts, so it *looks* hermetic. But it
# extends base.json (a declared dep) whose `include` glob is inherited. Without
# the sandbox that glob matches a leaked sibling .ts and pulls it in (TS2322).
function mk_extends_include() {
	local dir="$1"
	mkdir -p "$dir"
	echo '{"include": ["**/*.ts"]}' >"$dir/base.json"
	echo '{"extends": "./base.json", "files": ["source.ts"], "compilerOptions": {}}' >"$dir/tsconfig.json"
	echo 'export const x = 1;' >"$dir/source.ts"
	cat >"$dir/BUILD.bazel" <<-'EOF'
		load("@aspect_rules_ts//ts:defs.bzl", "ts_config", "ts_project")

		ts_config(
		    name = "tsconfig",
		    src = "tsconfig.json",
		    deps = ["base.json"],
		)

		ts_project(
		    name = "foo",
		    srcs = ["source.ts"],
		    tsconfig = ":tsconfig",
		)

		genrule(
		    name = "leak",
		    outs = ["bad.ts"],
		    cmd = "echo 'export const b: string = 123;' > $@",
		)
	EOF
	run bazel build "//$dir:leak"
	assert_success
}

@test 'extends include: sandbox ignores leaked .ts, local inherits the glob (TS2322)' {
	workspace
	mk_extends_include "ext_ok"
	mk_extends_include "ext_no"

	run bazel build //ext_ok:foo --strategy=TsProject=sandboxed
	assert_success

	run bazel build //ext_no:foo --strategy=TsProject=local
	assert_failure
	assert_output -p "bad.ts"
	assert_output -p "error TS2322"
}

# --- Scenario 7: a dep's .ts next to its .d.ts with isolated_typecheck --------
# With isolated_typecheck, :a's typecheck action should only see :b's .d.ts.
# But :b's b.ts is copied to bazel-bin right next to b.d.ts, and tsc resolves
# `../b/b` to the .ts before the .d.ts. The sandbox hides b.ts; without it tsc
# pulls b.ts into :a's program. That is harmless unless --rootDir is passed, in
# which case tsc rejects b.ts as outside rootDir (TS6059) even under --noEmit.
# --rootDir is only needed for emit, so it is not passed to the typecheck action.
function mk_isolated_typecheck_dep() {
	local dir="$1"
	mkdir -p "$dir/a" "$dir/b"
	echo 'export const b: number = 1;' >"$dir/b/b.ts"
	echo 'import { b } from "../b/b"; export const a: number = b;' >"$dir/a/a.ts"
	cat >"$dir/b/BUILD.bazel" <<-'EOF2'
		load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

		ts_project(
		    name = "b",
		    srcs = ["b.ts"],
		    declaration = True,
		    isolated_typecheck = True,
		    tsconfig = {"compilerOptions": {"declaration": True, "isolatedDeclarations": True}},
		    visibility = ["//visibility:public"],
		)
	EOF2
	cat >"$dir/a/BUILD.bazel" <<-EOF2
		load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

		ts_project(
		    name = "a",
		    srcs = ["a.ts"],
		    declaration = True,
		    isolated_typecheck = True,
		    tsconfig = {"compilerOptions": {"declaration": True, "isolatedDeclarations": True}},
		    deps = ["//$dir/b"],
		)
	EOF2
}

@test 'isolated_typecheck dep: local typecheck ignores the dep .ts outside rootDir (TS6059)' {
	workspace
	mk_isolated_typecheck_dep "itc_ok"
	mk_isolated_typecheck_dep "itc_no"

	run bazel build //itc_ok/a:a_typecheck --strategy=TsProjectCheck=sandboxed
	assert_success

	run bazel build //itc_no/a:a_typecheck --strategy=TsProjectCheck=local
	assert_success
	refute_output -p "TS6059"
}
