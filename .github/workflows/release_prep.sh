#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
TAG=${GITHUB_REF_NAME}
# Strip leading 'v'
PREFIX="rules_ts-${TAG:1}"
ARCHIVE="rules_ts-$TAG.tar.gz"

# Don't include examples in the distribution artifact, to reduce size
# Note, we do need to include e2e/bzlmod since BCR runs our test based on distribution artifact.
# Also stamp the release version into the repo
cat >.git/info/attributes <<EOF
examples                 export-ignore
ts/private/versions.bzl  export-subst
EOF

git archive --format=tar --prefix=${PREFIX}/ ${TAG} | gzip > $ARCHIVE
SHA=$(shasum -a 256 $ARCHIVE | awk '{print $1}')

cat << EOF
## Using [Bzlmod] with Bazel 6:

Add to your \`MODULE.bazel\` file:

\`\`\`starlark
bazel_dep(name = "aspect_rules_ts", version = "${TAG:1}")

rules_ts_ext = use_extension(
    "@aspect_rules_ts//ts:extensions.bzl",
    "ext",
    dev_dependency = True,
)

rules_ts_ext.deps()

use_repo(rules_ts_ext, "npm_typescript")
\`\`\`

[Bzlmod]: https://bazel.build/build/bzlmod

## Using WORKSPACE

Paste this snippet into your \`WORKSPACE\` file:

\`\`\`starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "aspect_rules_ts",
    sha256 = "${SHA}",
    strip_prefix = "${PREFIX}",
    url = "https://github.com/aspect-build/rules_ts/releases/download/${TAG}/${ARCHIVE}",
)
EOF

awk 'f;/--SNIP--/{f=1}' e2e/workspace/WORKSPACE
echo "\`\`\`" 
