set -o errexit

cd $( dirname -- "$BASH_SOURCE"; )


message() {
    echo "###########################"
    echo "$1"
}

exit_with_message() {
    message "FAIL: $1"
    exit 1
}

cleanup() {
    rm -f evil.ts included.ts
    git checkout HEAD -- tsconfig.json
}

# just run it in case there is leftovers
cleanup
# set up trap for graceful cleanup
trap cleanup EXIT


message "# Case 0; try to build a target that will never succeed"
message="error TS2322: Type 'number' is not assignable to type 'string'."
bazel build :should_fail 2>&1 | grep "$message" || exit_with_message "Case 0: expected worker to report \"$message\""
# we want fail.ts to stay bazel-out to see if subsequent cases ever read that file. 


message "# Case 1; warmed up worker reporting errors of evil.ts"
bazel build :ts
echo "evilcode = 1" > evil.ts
bazel build :ts && exit_with_message "Case 1: expected ts worker to report errors for evil.ts"

message="evil.ts(1,1): error TS2304: Cannot find name 'evilcode'."
bazel build :ts 2>&1 | grep "$message" || exit_with_message "Case 1: expected worker to report \"$message\" 
cleanup


message "# Case 2; warmed up worker stops reporting errors of removed file"
bazel build :ts
echo "evilcode = 1" > evil.ts
bazel build :ts && exit_with_message "Case 2: expected ts worker to report errors for evil.ts" 
rm evil.ts
bazel build :ts || exit_with_message "Case 2: expected ts worker to not report any errors for evil.ts" 
echo "evilcode = 1" > evil.ts
bazel build :ts && exit_with_message "Case 2: expected ts worker to report errors for evil.ts" 
cleanup


message "# Case 3; worker reports errors when the tsconfig changes"
bazel build :ts
echo '{"compilerOptions": {"noImplicitAny": true}}' > tsconfig.json

message="error TS7006: Parameter 'should_i' implicitly has an 'any' type."
bazel build :ts 2>&1 | grep "$message" || exit_with_message "Case 3: expected worker to report \"$message\""
cleanup
bazel build :ts


message "# Case 4: Builds with local strategy"
bazel clean
bazel build :lib --strategy=TsProject=local

message "All tests have passed"