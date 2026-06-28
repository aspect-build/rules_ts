#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

TOOL_VERSIONS_JQ_FILTER='
[
    .versions[]
    | select(.version | test("^[0-9.]+$"))
    | {key: .version, value: .dist.integrity}
] | from_entries
'

REGISTRY_JSON=$(mktemp)
NEW=$(mktemp)
trap 'rm -f "$REGISTRY_JSON" "$NEW"' EXIT

curl --silent https://registry.npmjs.org/typescript >"$REGISTRY_JSON"

awk '/NATIVE_TYPESCRIPT_VERSIONS =/ { exit } { print }' "$SCRIPT_DIR/versions.bzl" >"$NEW"

RC_VERSION=$(jq -r '."dist-tags".rc // empty' "$REGISTRY_JSON")
echo "NATIVE_TYPESCRIPT_VERSIONS = {" >>"$NEW"
if [[ -n "$RC_VERSION" ]]; then
	echo "    \"$RC_VERSION\": {" >>"$NEW"
	rc_integrity=$(jq -r --arg rc "$RC_VERSION" '.versions[] | select(.version == $rc) | .dist.integrity' "$REGISTRY_JSON")
	echo "        \"integrity\": \"$rc_integrity\"," >>"$NEW"
	echo "        \"native_package_integrities\": {" >>"$NEW"
	jq -r --arg rc "$RC_VERSION" '
        .versions[]
        | select(.version == $rc)
        | (.optionalDependencies // {})
        | keys[]
        | select(startswith("@typescript/"))
    ' "$REGISTRY_JSON" | while read -r package_name; do
		native_package="${package_name#@typescript/}"
		package_url_name="${package_name/\//%2f}"
		integrity=$(curl --silent "https://registry.npmjs.org/${package_url_name}/${RC_VERSION}" | jq -r '.dist.integrity')
		echo "            \"$native_package\": \"$integrity\"," >>"$NEW"
	done
	echo "        }," >>"$NEW"
	echo "    }," >>"$NEW"
fi
echo "}" >>"$NEW"
echo "" >>"$NEW"

echo -n "TOOL_VERSIONS = " >>"$NEW"
jq "$TOOL_VERSIONS_JQ_FILTER" "$REGISTRY_JSON" >>"$NEW"

cp "$NEW" "$SCRIPT_DIR/versions.bzl"
