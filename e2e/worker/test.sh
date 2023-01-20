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

bzl=$(which bazel)

bazel() {
  "$bzl" "${STARTUP_OPTIONS[@]+"${STARTUP_OPTIONS[@]}"}" $@ "${ARGS[@]+"${ARGS[@]}"}"
}


message() {
    echo ""
    echo "###########################"
    echo "#$1"
    echo ""
}

exit_with_message() {
    echo ""
    echo "## FAIL: $1"
    echo ""
    exit 1
}

add_trap() {
    traps="$@; $traps"
    trap "(set +e; $traps)" EXIT
}


message "# Case X: Should dump traces"
bazel build //trace

traces=$(mktemp -d)
rm -rf "$traces"
echo $traces

buildozer "add args --generateTrace $traces" //trace
add_trap "buildozer 'remove args' //trace"

bazel build //trace
[ ! -d $traces ] && exit_with_message "Case X: Expected tsc to write traces"

bazel build //trace --action_env=ANALYSIS_CACHE_BUST=1


echo ""
echo "###########################"
echo "## All tests have passed ##"
echo "###########################"
echo ""

echo "## Running cleanup"
echo ""