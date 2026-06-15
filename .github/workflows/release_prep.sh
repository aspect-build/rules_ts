#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Argument provided by reusable workflow caller, see
# https://github.com/bazel-contrib/.github/blob/d197a6427c5435ac22e56e33340dff912bc9334e/.github/workflows/release_ruleset.yaml#L72
TAG=$1
# Strip leading 'v'
PREFIX="rules_ts-${TAG:1}"
ARCHIVE="rules_ts-$TAG.tar.gz"

# NB: configuration for 'git archive' is in /.gitattributes
git archive --format=tar --prefix=${PREFIX}/ ${TAG} | gzip >$ARCHIVE

# Add generated API docs to the release
# see https://github.com/bazelbuild/bazel-central-registry/blob/main/docs/stardoc.md
./.github/workflows/release_docs.sh "$GITHUB_WORKSPACE/${ARCHIVE%.tar.gz}.docs.tar.gz"

cat <<EOF
## Using [Bzlmod]:

Add to your \`MODULE.bazel\` file:

\`\`\`starlark
bazel_dep(name = "aspect_rules_ts", version = "${TAG:1}")

rules_ts_ext = use_extension("@aspect_rules_ts//ts:extensions.bzl", "ext", dev_dependency = True)

rules_ts_ext.deps(
    ts_version_from = "//:package.json",
)

use_repo(rules_ts_ext, "npm_typescript")
\`\`\`

[Bzlmod]: https://bazel.build/build/bzlmod
EOF
