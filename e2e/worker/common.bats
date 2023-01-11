load "bats-support/load"
load "bats-assert/load"

function workspace() {
    local rules_ts_path="$(realpath $BATS_TEST_DIRNAME/../../)"
    local -i is_npm_translate_lock=0
    while (( $# > 0 )); do
        case "$1" in
        -t|--npm-translate-lock) is_npm_translate_lock=1; shift ;;
        *) break ;;
        esac
    done

    cat > WORKSPACE <<EOF
local_repository(
    name = "aspect_rules_ts",
    path = "$rules_ts_path",
)

load("@aspect_rules_ts//ts:repositories.bzl", "LATEST_VERSION", "rules_ts_dependencies")

rules_ts_dependencies(ts_version = LATEST_VERSION)

# Fetch and register node, if you haven't already
load("@rules_nodejs//nodejs:repositories.bzl", "DEFAULT_NODE_VERSION", "nodejs_register_toolchains")

nodejs_register_toolchains(
    name = "node",
    node_version = DEFAULT_NODE_VERSION,
)
EOF

  cat > .bazelrc << EOF
startup --max_idle_secs=10
build --worker_verbose
EOF

  if (( is_npm_translate_lock )); then
    cat >> WORKSPACE <<EOF
load("@aspect_rules_js//npm:npm_import.bzl", "npm_translate_lock")

npm_translate_lock(
    name = "npm",
    pnpm_lock = "//:pnpm-lock.yaml",
)

load("@npm//:repositories.bzl", "npm_repositories")

npm_repositories()  
EOF
  fi
}

function tsconfig() {
    echo "{}" > tsconfig.json
}


function ts_project() {
    local -a deps=()
    local -a srcs=()
    local -a name="foo"
    local -a tsconfig="tsconfig.json"
    local -a npm_link_all_packages="#"
    while (( $# > 0 )); do
        case "$1" in
        --tsconfig) shift; tsconfig="$1"; shift ;;
        -n|--name) shift; name="$1"; shift ;;
        -l|--npm-link-all-packages) npm_link_all_packages=""; shift ;;
        -d|--dep) shift; deps+=( "\"$1"\" ); shift ;;
        -s|--src) shift; srcs+=( "\"$1\"" ); shift ;;
        --) shift; break ;;
        *) break ;;
        esac
    done
    local -a deps_joined=$(IFS=, ; echo "${deps[*]}")
    local -a srcs_joined=$(IFS=, ; echo "${srcs[*]}")
    cat > BUILD.bazel <<EOF
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
${npm_link_all_packages}load("@npm//:defs.bzl", "npm_link_all_packages")
${npm_link_all_packages}npm_link_all_packages(name = "node_modules")

ts_project(
    name = "${name}",
    srcs = [${srcs_joined}],
    tsconfig = "${tsconfig}",
    deps = [${deps_joined}]
)
EOF
}