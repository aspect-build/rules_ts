workspace(name = "aspect_rules_ts")

load(":internal_deps.bzl", "rules_ts_internal_deps")

# Fetch deps needed only locally for development
rules_ts_internal_deps()

load("//ts:repositories.bzl", "rules_ts_bazel_dependencies", "rules_ts_dependencies")

# Fetch dependencies which users need as well
# Note, we have to be different and first load just the bazel dependencies, since we
# need to bootstrap rules_nodejs before we can load from @npm to get our typescript version.
rules_ts_bazel_dependencies()

load("@aspect_rules_js//js:repositories.bzl", "rules_js_dependencies")

rules_js_dependencies()

load("@aspect_rules_js//js:toolchains.bzl", "DEFAULT_NODE_VERSION", "rules_js_register_toolchains")

rules_js_register_toolchains(node_version = DEFAULT_NODE_VERSION)

load("@rules_nodejs//nodejs:repositories.bzl", "nodejs_register_toolchains")

nodejs_register_toolchains(
    name = "node18",
    node_version = "18.12.0",
)

load("@aspect_rules_swc//swc:repositories.bzl", "LATEST_SWC_VERSION", "swc_register_toolchains")

swc_register_toolchains(
    name = "swc",
    swc_version = LATEST_SWC_VERSION,
)

# For running our own unit tests
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

############################################
# Gazelle, for generating bzl_library targets
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.19.3")

gazelle_dependencies()

############################################
# Stardoc
load("@io_bazel_stardoc//:setup.bzl", "stardoc_repositories")

stardoc_repositories()

load("@rules_jvm_external//:repositories.bzl", "rules_jvm_external_deps")

rules_jvm_external_deps()

load("@rules_jvm_external//:setup.bzl", "rules_jvm_external_setup")

rules_jvm_external_setup()

load("@io_bazel_stardoc//:deps.bzl", "stardoc_external_deps")

stardoc_external_deps()

load("@stardoc_maven//:defs.bzl", stardoc_pinned_maven_install = "pinned_maven_install")

stardoc_pinned_maven_install()

# Buildifier
load("@buildifier_prebuilt//:deps.bzl", "buildifier_prebuilt_deps")

buildifier_prebuilt_deps()

load("@buildifier_prebuilt//:defs.bzl", "buildifier_prebuilt_register_toolchains")

buildifier_prebuilt_register_toolchains()

###########################################
# A pnpm workspace so we can test 3p deps
load("@aspect_rules_js//npm:repositories.bzl", "npm_translate_lock")

npm_translate_lock(
    name = "npm",
    pnpm_lock = "//examples:pnpm-lock.yaml",
    verify_node_modules_ignored = "//:.bazelignore",
)

load("@npm//:repositories.bzl", "npm_repositories")

npm_repositories()

# You can verify the typescript version used by Bazel:
# bazel run -- @npm_typescript//:tsc --version
rules_ts_dependencies(ts_version_from = "@npm//examples:typescript/resolved.json")

###########################################
# Protobuf rules to test ts_proto_library
load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies")

rules_proto_dependencies()

# rules_lint
load(
    "@aspect_rules_lint//format:repositories.bzl",
    "fetch_shfmt",
)

fetch_shfmt()
