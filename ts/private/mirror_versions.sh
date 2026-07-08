#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Stable v6 and below only: v7+ lives in NATIVE_TYPESCRIPT_VERSIONS instead so
# LATEST_TYPESCRIPT_VERSION (TOOL_VERSIONS.keys()[-1], the default ts_version)
# does not silently switch to the native compiler.
TOOL_VERSIONS_JQ_FILTER='
[
    .versions[]
    | select((.version | test("^[0-9.]+$")) and ((.version | split(".")[0] | tonumber) < 7))
    | {key: .version, value: .dist.integrity}
] | from_entries
'

# Versions shipping the native (tsgo) compiler: every stable v7+ version, plus
# the current rc dist-tag (if any), plus every version already mirrored in
# versions.bzl. These are kept out of TOOL_VERSIONS and need the integrity of
# each platform-specific @typescript/typescript-* package.
#
# Prereleases persist after the rc dist-tag moves on; delete an entry from
# versions.bzl to retire it (like rules_nodejs node versions).
NATIVE_VERSIONS_JQ_SELECT='
    select(
        ((.version | test("^[0-9.]+$")) and ((.version | split(".")[0] | tonumber) >= 7))
        or .version == $rc
        or IN(.version; $existing[])
    )
'

NATIVE_VERSIONS_JQ_FILTER='
[
    .versions[]
    | '"$NATIVE_VERSIONS_JQ_SELECT"'
    | .version as $version
    | {
        key: $version,
        value: {
            integrity: .dist.integrity,
            native_package_integrities: ([
                (.optionalDependencies // {})
                | keys[]
                | select(startswith("@typescript/"))
                | {
                    key: sub("^@typescript/"; ""),
                    value: ($platforms[0][.][$version] // error("no mirrored integrity for \(.)@\($version)")),
                }
            ] | from_entries),
        },
    }
] | from_entries
'

REGISTRY_JSON=$(mktemp)
PLATFORMS_JSON=$(mktemp)
NEW=$(mktemp)
trap 'rm -f "$REGISTRY_JSON" "$PLATFORMS_JSON" "$NEW"' EXIT

curl --silent https://registry.npmjs.org/typescript >"$REGISTRY_JSON"

RC_VERSION=$(jq -r '."dist-tags".rc // empty' "$REGISTRY_JSON")

# Version keys already mirrored in versions.bzl, as a JSON array. Top-level
# keys are indented 4 spaces; nested package keys are indented further.
EXISTING_NATIVE_VERSIONS=$(
	awk '/^NATIVE_TYPESCRIPT_VERSIONS = {/,/^}/' "$SCRIPT_DIR/versions.bzl" |
		sed -n 's/^    "\([^"]*\)": {$/\1/p' |
		jq --raw-input --null-input '[inputs]'
)

# Fetch each platform-specific package used by any native version once,
# reducing its registry metadata to {package: {version: integrity}}.
jq -r --arg rc "$RC_VERSION" --argjson existing "$EXISTING_NATIVE_VERSIONS" '
    [
        .versions[]
        | '"$NATIVE_VERSIONS_JQ_SELECT"'
        | (.optionalDependencies // {})
        | keys[]
        | select(startswith("@typescript/"))
    ]
    | unique | .[]
' "$REGISTRY_JSON" | while read -r package_name; do
	curl --silent "https://registry.npmjs.org/${package_name/\//%2f}" |
		jq '{(.name): (.versions | map_values(.dist.integrity))}'
done | jq --slurp 'add // {}' >"$PLATFORMS_JSON"

awk '/NATIVE_TYPESCRIPT_VERSIONS =/ { exit } { print }' "$SCRIPT_DIR/versions.bzl" >"$NEW"

echo -n "NATIVE_TYPESCRIPT_VERSIONS = " >>"$NEW"
jq --arg rc "$RC_VERSION" --argjson existing "$EXISTING_NATIVE_VERSIONS" --slurpfile platforms "$PLATFORMS_JSON" "$NATIVE_VERSIONS_JQ_FILTER" "$REGISTRY_JSON" >>"$NEW"
echo "" >>"$NEW"

echo -n "TOOL_VERSIONS = " >>"$NEW"
jq "$TOOL_VERSIONS_JQ_FILTER" "$REGISTRY_JSON" >>"$NEW"

cp "$NEW" "$SCRIPT_DIR/versions.bzl"

# jq emits 2-space indentation; reformat to the repo's buildifier style so the
# generated file is committable as-is without a separate manual step.
npx @bazel/buildifier "$SCRIPT_DIR/versions.bzl"
