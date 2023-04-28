bats_load_library "bats-support"
bats_load_library "bats-assert"

function workspace() {
    local rules_ts_path="$(realpath $BATS_TEST_DIRNAME/../../)"
    local -i is_npm_translate_lock=0
    local -i no_convenience_symlinks=0
    while (( $# > 0 )); do
        case "$1" in
        -t|--npm-translate-lock) is_npm_translate_lock=1; shift ;;
        -t|--noconvenience-symlinks) no_convenience_symlinks=1; shift ;;
        *) break ;;
        esac
    done

    cat > WORKSPACE <<EOF
local_repository(
    name = "aspect_rules_ts",
    path = "$rules_ts_path",
)

load("@aspect_rules_ts//ts:repositories.bzl", "rules_ts_dependencies")

rules_ts_dependencies(ts_version = "5.0.4")

# Fetch and register node, if you haven't already
load("@rules_nodejs//nodejs:repositories.bzl", "DEFAULT_NODE_VERSION", "nodejs_register_toolchains")

nodejs_register_toolchains(
    name = "node",
    node_version = DEFAULT_NODE_VERSION,
)

load("@aspect_bazel_lib//lib:repositories.bzl", "register_copy_directory_toolchains", "register_copy_to_directory_toolchains")
register_copy_directory_toolchains()
register_copy_to_directory_toolchains()
EOF


  [[ -e "$BATS_TEST_DIRNAME/.bazelversion" ]] && cp "$BATS_TEST_DIRNAME/.bazelversion" .bazelversion

  cat > .bazelrc << EOF
try-import $BATS_TEST_DIRNAME/.bazelrc
startup --max_idle_secs=10
build --worker_verbose
EOF


  if (( no_convenience_symlinks )); then
    echo "build --noexperimental_convenience_symlinks" >> .bazelrc
  fi

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
    local path="."
    local no_implicit_any="false"
    local isolated_modules="false"
    local source_map="false"
    local declaration="false"
    local target="ES2020"
    local module_resolution="node"
    local composite="false"
    local trace_resolution="false"
    local extended_diagnostics="false"
    while (( $# > 0 )); do
        case "$1" in
        --path) shift; path="$1"; shift ;;
        --no-implicit-any) no_implicit_any="true"; shift ;;
        --isolated-modules) isolated_modules="true"; shift ;;
        --source-map) source_map="true"; shift ;;
        --declaration) declaration="true"; shift ;;
        --composite) composite="true"; shift ;;
        --target) shift; target="$1"; shift ;;
        --module-resolution) shift; module_resolution="$1"; shift ;;
        --trace-resolution) trace_resolution="true"; shift ;;
        --extended-diagnostics) extended_diagnostics="true"; shift ;;
        *) break ;;
        esac
    done
    cat > "$path/tsconfig.json" <<EOF
{
    "compilerOptions": {
        "noImplicitAny": $no_implicit_any,
        "isolatedModules": $isolated_modules,
        "sourceMap": $source_map,
        "declaration": $declaration,
        "target": "$target",
        "moduleResolution": "$module_resolution",
        "traceResolution": $trace_resolution,
        "extendedDiagnostics": $extended_diagnostics,
        "composite": $composite
    }
}
EOF
}


function ts_project() {
    local path="."
    local out_dir="."
    local name="foo"
    local -a deps=()
    local -a srcs=()
    local -a args=()
    local tsconfig="tsconfig.json"
    local npm_link_all_packages="#"
    local source_map=""
    local declaration=""
    local composite=""
    while (( $# > 0 )); do
        case "$1" in
        --path) shift; path="$1"; shift ;;
        --out_dir) shift; out_dir="$1"; shift ;;
        --tsconfig) shift; tsconfig="$1"; shift ;;
        -n|--name) shift; name="$1"; shift ;;
        -l|--npm-link-all-packages) npm_link_all_packages=""; shift ;;
        -d|--dep) shift; deps+=( "\"$1"\" ); shift ;;
        -s|--src) shift; srcs+=( "\"$1\"" ); shift ;;
        --arg) shift; args+=( "\"$1\"" "\"$2\"" ); shift; shift ;;
        --source-map) shift; source_map="source_map = True," ;;
        --declaration) shift; declaration="declaration = True," ;;
        --composite) shift; composite="composite = True," ;;
        --) shift; break ;;
        *) break ;;
        esac
    done
    local deps_joined=$(IFS=, ; echo "${deps[*]}")
    local srcs_joined=$(IFS=, ; echo "${srcs[*]}")
    local args_joined=$(IFS=, ; echo "${args[*]}")
    cat > "$path/BUILD.bazel" <<EOF
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
${npm_link_all_packages}load("@npm//:defs.bzl", "npm_link_all_packages")
${npm_link_all_packages}npm_link_all_packages(name = "node_modules")

ts_project(
    name = "${name}",
    visibility = ["//visibility:public"],
    srcs = [${srcs_joined}],
    tsconfig = "${tsconfig}",
    out_dir = "${out_dir}",
    deps = [${deps_joined}],
    args = [${args_joined}],
    $source_map
    $declaration
    $composite
)
EOF
}

function js_library() {
    local path="."
    local name="foo"
    local npm_link_all_packages="#"
    local -a srcs=()
    while (( $# > 0 )); do
        case "$1" in
        --path) shift; path="$1"; shift ;;
        -n|--name) shift; name="$1"; shift ;;
        -s|--src) shift; srcs+=( "\"$1\"" ); shift ;;
        -l|--npm-link-all-packages) npm_link_all_packages=""; shift ;;
        --) shift; break ;;
        *) break ;;
        esac
    done
    local -a srcs_joined=$(IFS=, ; echo "${srcs[*]}")
    cat > "$path/BUILD.bazel" <<EOF
load("@aspect_rules_js//js:defs.bzl", "js_library")
${npm_link_all_packages}load("@npm//:defs.bzl", "npm_link_all_packages")
${npm_link_all_packages}npm_link_all_packages(name = "node_modules")

js_library(
    name = "${name}",
    visibility = ["//visibility:public"],
    srcs = [${srcs_joined}]
)
EOF
}

function npm_package() {
    local path="."
    local name="foo"
    local -a srcs=()
    while (( $# > 0 )); do
        case "$1" in
        --path) shift; path="$1"; shift ;;
        -n|--name) shift; name="$1"; shift ;;
        -s|--src) shift; srcs+=( "\"$1\"" ); shift ;;
        --) shift; break ;;
        *) break ;;
        esac
    done
    local -a srcs_joined=$(IFS=, ; echo "${srcs[*]}")
    cat >> "$path/BUILD.bazel" <<EOF
load("@aspect_rules_js//npm:defs.bzl", "npm_package")

npm_package(
    name = "${name}",
    visibility = ["//visibility:public"],
    srcs = [${srcs_joined}]
)
EOF
}