#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

JQ_FILTER='
[
    .versions[]
    | select(.version | test("^[0-9.]+$"))
    | {key: .version, value: .dist.integrity}
] | from_entries
'

NEW=$(mktemp)
sed '/TOOL_VERSIONS =/Q' $SCRIPT_DIR/versions.bzl >$NEW
echo -n "TOOL_VERSIONS = " >>$NEW
curl --silent https://registry.npmjs.org/typescript | jq "$JQ_FILTER" >>$NEW

cp $NEW $SCRIPT_DIR/versions.bzl
