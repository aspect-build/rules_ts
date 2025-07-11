#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
TAG=${GITHUB_REF_NAME}
# Strip leading 'v'
PREFIX="rules_ts-${TAG:1}"
ARCHIVE="rules_ts-$TAG.tar.gz"

# NB: configuration for 'git archive' is in /.gitattributes
git archive --format=tar --prefix=${PREFIX}/ ${TAG} | gzip >$ARCHIVE
SHA=$(shasum -a 256 $ARCHIVE | awk '{print $1}')

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

## Using legacy WORKSPACE

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

awk 'f;/--SNIP--/{f=1}' e2e/smoke/WORKSPACE
echo "\`\`\`"

cat <<EOF

To use rules_ts with bazel-lib 2.x, you must additionally register the coreutils toolchain.

\`\`\`starlark
load("@aspect_bazel_lib//lib:repositories.bzl", "register_coreutils_toolchains")

register_coreutils_toolchains()
\`\`\`
EOF
