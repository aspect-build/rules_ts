# Declare the local Bazel workspace.
workspace(
    # If your ruleset is "official"
    # (i.e. is in the bazelbuild GitHub org)
    # then this should just be named "rules_ts"
    # see https://docs.bazel.build/versions/main/skylark/deploying.html#workspace
    name = "aspect_rules_ts",
)

load(":internal_deps.bzl", "rules_ts_internal_deps")

# Fetch deps needed only locally for development
rules_ts_internal_deps()

load("//ts:repositories.bzl", "rules_ts_dependencies")

# Fetch dependencies which users need as well
# You can verify the typescript version used by Bazel:
# bazel run -- @npm_typescript//:tsc --version
rules_ts_dependencies(ts_version_from = "//:package.json")

load("@rules_nodejs//nodejs:repositories.bzl", "nodejs_register_toolchains")

nodejs_register_toolchains(
    name = "node16",
    node_version = "16.9.0",
)

# For running our own unit tests
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

############################################
# Gazelle, for generating bzl_library targets
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.17.2")

gazelle_dependencies()
