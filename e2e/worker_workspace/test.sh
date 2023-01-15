set -o errexit

cd $( dirname -- "$BASH_SOURCE"; )

STARTUP_OPTIONS=( )
ARGS=( )

while (( $# > 0 )); do
  case $1 in
    (--bazelrc)
      STARTUP_OPTIONS+=( "$2" )
      shift
      shift;;
    (--bazelrc=*) 
      STARTUP_OPTIONS+=( "$1" )
      shift;;
    (*) 
      ARGS+=( "$1" )
      shift;;
  esac
done

bazel() {
    command bazel "${STARTUP_OPTIONS[@]+"${STARTUP_OPTIONS[@]}"}" $@ "${ARGS[@]+"${ARGS[@]}"}"
}


# asserts that in a cold start missing deps are reported correctly and succeeds in a subsequent build
# where missing deps are in place.
# Discovered in: https://github.com/aspect-build/bazel-examples/tree/js_build_file_generation
set -x

buildozer "remove deps //apps/triad/pivot //apps/triad/vibe" //apps/triad:triad_ts
bazel build //apps/triad:triad_ts

set -o errexit
buildozer "add deps //apps/triad/pivot //apps/triad/vibe" //apps/triad:triad_ts
bazel build //apps/triad:triad_ts
