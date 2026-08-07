#!/usr/bin/env bash
# Proves a few things about ts_project's and ts_validate_options's opportunistic
# use of js_binary_lib.run_binary_action (ts/private/ts_lib.bzl):
#
# 1. It lets Bazel's path mapping share a single cached action between two
#    builds that differ only in compilation mode.
# 2. It is advertised via the "supports-path-mapping" execution requirement.
#
# A shared --disk_cache is required: -c opt and -c fastbuild are different
# configurations, so each gets its own action instance the first time Bazel
# visits it in a given build graph -- the incremental "did anything change"
# check within one build never gets a chance to compare across them. Only an
# explicit disk (or remote) cache lookup, keyed by the path-mapped action
# digest, can serve the second build's action from the first build's result.
set -o errexit -o nounset -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
disk_cache="$scratch/disk_cache"
exec_log="$scratch/exec_log.json"

# Both actions under test use use_default_shell_env, so this env var forces
# them to be treated as new on every run of this script -- that way a prior
# local build of the same target/config (e.g. from an earlier run of this
# script, or from another CI step) can't let Bazel skip them as already
# up-to-date, which would prevent them from ever consulting our disk cache.
invalidate="$(date +%s)"

# //:lib_isolated_typecheck sets isolated_typecheck = True, which makes tsc
# type-checking run as its own TsProjectCheck action separate from the
# TsProject(Emit) action. That action is only built as part of the
# "_typecheck" filegroup target the ts_project macro generates, not as part of
# the default outputs. This is what exercises run_binary_action's use in
# ts_project's isolated typecheck action.
targets=(//:lib //:lib_isolated_typecheck_typecheck)

bazel build -c fastbuild "${targets[@]}" \
	--disk_cache="$disk_cache" \
	--action_env="TS_PROJECT_PATH_MAPPING_TEST_INVALIDATE=$invalidate"

bazel build -c opt "${targets[@]}" \
	--disk_cache="$disk_cache" \
	--action_env="TS_PROJECT_PATH_MAPPING_TEST_INVALIDATE=$invalidate" \
	--execution_log_json_file="$exec_log"

# mnemonic:target pairs to check via aquery. The target must be the
# underlying ts_project rule itself (not a wrapping filegroup) since aquery
# does not surface a filegroup's generating action when it re-exports a
# non-default output group, as the "_typecheck" filegroup does.
mnemonic_targets=(
	"TsProject:lib"
	"TsValidateOptions:lib"
	"TsProjectCheck:lib_isolated_typecheck"
)

for entry in "${mnemonic_targets[@]}"; do
	mnemonic="${entry%%:*}"
	target="${entry#*:}"

	matches="$(jq -s --arg mnemonic "$mnemonic" '[.[] | select(.mnemonic == $mnemonic)]' "$exec_log")"
	count="$(echo "$matches" | jq 'length')"
	if [ "$count" -eq 0 ]; then
		echo "FAIL: no $mnemonic entry found in the -c opt execution log" >&2
		exit 1
	fi

	cache_hit="$(echo "$matches" | jq -r '.[0].cacheHit')"
	if [ "$cache_hit" != "true" ]; then
		echo "FAIL: $mnemonic action was re-executed under -c opt (cacheHit=$cache_hit); path mapping did not share the cache entry from -c fastbuild" >&2
		exit 1
	fi

	echo "PASS: $mnemonic action was cache-shared across -c fastbuild and -c opt"

	# We should find via bazel aquery that the action advertises path-mapping
	# support.
	aquery_output="$(bazel aquery "mnemonic(\"$mnemonic\", //:$target)")"
	if ! echo "$aquery_output" | grep -q "supports-path-mapping"; then
		echo "FAIL: supports-path-mapping was not advertised for the $mnemonic action of //:$target" >&2
		echo "$aquery_output" >&2
		exit 1
	fi

	echo "PASS: supports-path-mapping is advertised for the $mnemonic action of //:$target"
done
