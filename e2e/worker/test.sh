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


message "# Case 0; try to build a target that will never succeed"
message="error TS2322: Type 'number' is not assignable to type 'string'." 
bazel build :should_fail 2>&1 | grep "$message" || exit_with_message "Case 0: expected worker to report \"$message\""
# we want fail.ts to be present within bazel-out to see if subsequent cases ever try to read the file. 


message "# Case 1; warmed up worker reporting errors of evil.ts"
bazel build :ts

add_trap "rm -f evil.ts"
echo "evilcode = 1" > evil.ts

message="evil.ts(1,1): error TS2304: Cannot find name 'evilcode'."
bazel build :ts 2>&1 | grep "$message" || exit_with_message "Case 1: expected worker to report \"$message\""
rm evil.ts


message "# Case 2; warmed up worker stops reporting errors of removed file"
bazel build :ts

add_trap "rm -f evil.ts"
echo "evilcode = 1" > evil.ts

bazel build :ts && exit_with_message "Case 2: expected ts worker to report errors for evil.ts" 
rm evil.ts
bazel build :ts || exit_with_message "Case 2: expected ts worker to not report any errors for evil.ts" 


message "# Case 3; worker reports errors when the tsconfig changes"

add_trap "git checkout HEAD -- tsconfig.json"
echo '{"compilerOptions": {"noImplicitAny": true, "module": "ES2020", "moduleResolution": "node"}}' > tsconfig.json

message="error TS7006: Parameter 'should_i' implicitly has an 'any' type."
bazel build :ts 2>&1 | (grep "$message" || exit_with_message "Case 3: expected worker to report \"$message\"")
git checkout HEAD -- tsconfig.json


message "# Case 4; assert that tsc does not read a file that's been removed from srcs"
for i in $(seq 0 9)
do
    echo "const a = $i" > "_addendum_$i.ts"
    add_trap "rm -f _addendum_$i.ts"

    bazel build :ts
    rm "_addendum_$i.ts"
    bazel build :ts
done


message "# Case 5; tsc can handle tsconfig change, file addendum and removal in one batch"

add_trap "rm -f _addendum_1.ts"
echo "const a1 = 1" > "_addendum_1.ts"
bazel build :ts

add_trap "git checkout HEAD -- tsconfig.json"
echo '{"compilerOptions": {"module": "ES2015", "moduleResolution": "node"}}' > tsconfig.json # tsconfig change

add_trap "rm -f _addendum_2.ts"
echo "const a2 = 2" > "_addendum_2.ts" # add

rm "_addendum_1.ts" # remove

bazel build :ts
rm "_addendum_2.ts"


message "# Case 6: Builds with sandboxed strategy"
bazel build :lib --strategy=TsProject=sandboxed


message "# Case 8: Should report missing deps"
for i in $(seq 1 4)
do
    add_trap "buildozer 'add deps //feature$i' :ts"
    buildozer "remove deps //feature$i" :ts

    message="error TS2307: Cannot find module './feature$i' or its corresponding type declarations."
    bazel build :ts | grep "$message" && exit_with_message "Case 8: Expected worker to report missing deps"

    buildozer "add deps //feature$i" :ts
    bazel build :ts
done


message "# Case 9: Should report multiple missing deps"

add_trap "buildozer 'add deps //feature1 //feature2 //feature3' :ts"

message1="error TS2307: Cannot find module './feature1' or its corresponding type declarations."
message2="error TS2307: Cannot find module './feature2' or its corresponding type declarations."
message3="error TS2307: Cannot find module './feature3' or its corresponding type declarations."

buildozer "remove deps //feature3" :ts
bazel build :ts || echo "test"
bazel build :ts 2>&1 | (grep "$message3" || exit_with_message "Case 9: expected worker to report \"$message3\"")


buildozer "add deps //feature3" :ts
buildozer "remove deps //feature1 //feature2" :ts
bazel build :ts 2>&1 | grep "$message1" || exit_with_message "Case 9: expected worker to report \"$message1\""
bazel build :ts 2>&1 | grep "$message2" || exit_with_message "Case 9: expected worker to report \"$message2\""
bazel build :ts 2>&1 | grep "$message3" && exit_with_message "Case 9: expected worker to not report \"$message3\""
buildozer 'add deps //feature1 //feature2 //feature3' :ts


message "# Case 10: Should report when @types/<pkg> and <pkg> is missing from deps."

add_trap "buildozer 'add deps //:node_modules/debug //:node_modules/@types/debug' :ts"
buildozer "remove deps //:node_modules/debug //:node_modules/@types/debug" :ts
message="error TS2307: Cannot find module 'debug' or its corresponding type declarations."
bazel build :ts || echo "test"
bazel build :ts 2>&1 | (grep "$message" || exit_with_message "Case 10: expected worker to report \"$message\"")
buildozer "add deps //:node_modules/debug //:node_modules/@types/debug" :ts


message "# Case 11: Should report missing third party deps"

deps=( "@nestjs/core" "rxjs" )

for dep in "${deps[@]}"; do
    add_trap "buildozer 'add deps //:node_modules/$dep' :ts"
    buildozer "remove deps //:node_modules/$dep" :ts
    message="error TS2307: Cannot find module '$dep' or its corresponding type declarations."
    bazel build :ts 2>&1 | grep "$message" || exit_with_message "Case 11: expected worker to report \"$message\""
    buildozer "add deps //:node_modules/$dep" :ts
    bazel build :ts || exit_with_message "Case 11: expected worker to not fail"
done


message "# Case 12: .tsbuildinfo file should be written when analysis cache is discarded."
bazel build //composite || exit_with_message "Case 12: expected worker to build without errors."
bazel build //composite --action_env=ANALYSIS_CACHE_BUST=1 || exit_with_message "Case 12: expected worker to build without errors. (subsequent)"


message "# Case 13: should not ignore new transitive deps"

message="error TS2307: Cannot find module '@transitive_closure/b' or its corresponding type declarations."
bazel build //transitive_closure 2>&1 | grep "$message" || exit_with_message "Case 13: expected worker to report \"$message\""

lockfile_backup=$(mktemp)
cat pnpm-lock.yaml > $lockfile_backup
add_trap "cat $lockfile_backup > pnpm-lock.yaml"


tmp=$(mktemp -d)
jq '.pnpm.packageExtensions["@transitive_closure/a"].dependencies["@transitive_closure/b"] = "workspace:*"' package.json > "$tmp/package.json"
pnpm install --lockfile-only --dir "$tmp" --store-dir $(mktemp -d) --virtual-store-dir $(mktemp -d)
cat "$tmp/pnpm-lock.yaml" > pnpm-lock.yaml

bazel build //transitive_closure 2>&1  | grep "$message" && exit_with_message "Case 13: expected worker to not report \"$message\""


message "# Case 14: should handle dependency version change"

lockfile_backup=$(mktemp)
cat pnpm-lock.yaml > $lockfile_backup
add_trap "cat $lockfile_backup > pnpm-lock.yaml"

tmp=$(mktemp -d)

jq '.dependencies["@types/node"] = "18.6.1"' package.json > "$tmp/package.json"
pnpm install --lockfile-only --dir "$tmp"
cat "$tmp/pnpm-lock.yaml" > pnpm-lock.yaml

message="node_modules/.aspect_rules_js/@types+node@18.6.1/node_modules/@types/node/globals.d.ts(72,13): error TS2403: Subsequent variable declarations must have the same type.  Variable 'AbortSignal' must be of type '{ new (): AbortSignal; prototype: AbortSignal; abort(reason?: any): AbortSignal; timeout(milliseconds: number): AbortSignal; }', but here has type '{ new (): AbortSignal; prototype: AbortSignal; }'."
bazel build :ts 2>&1  | grep "$message" || exit_with_message "Case 14: expected worker to report \"$message\""


jq '.dependencies["@types/node"] = "18.11.9"' package.json > "$tmp/package.json"
pnpm install --lockfile-only --dir "$tmp"
cat "$tmp/pnpm-lock.yaml" > pnpm-lock.yaml

bazel build :ts 2>&1 || exit_with_message "Case 14: expected worker to not fail"
cat $lockfile_backup > pnpm-lock.yaml

message "# Case 15: should print diagnostics with --worker_verbose flag"

bazel build :ts --worker_quit_after_build
echo "const a = $(date +%s)" > "_addendum_x.ts"
add_trap "rm -f _addendum_x.ts"

OUTPUT=$(mktemp)
bazel build :ts --worker_verbose 2> $OUTPUT
LOGPATH=$(cat $OUTPUT | grep -o "/.*-TsProject.log")

cat $LOGPATH | grep "# Beginning new work" || exit_with_message "Case 15: expected worker log to contain '# Beginning new work'"
cat $LOGPATH | grep "# Finished the work" || exit_with_message "Case 15: expected worker log to contain '# Finished the work'"
cat $LOGPATH | grep "creating a new worker with the key" || exit_with_message "Case 15: expected worker log to contain 'creating a new worker with the key'"
rm -f _addendum_x.ts

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