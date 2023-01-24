load "common.bats"

setup() {
    cd $(mktemp -d)
}

teardown() {
    bazel shutdown
    rm -rf $BATS_FILE_TMPDIR/*
}


@test 'should print diagnostics with --worker_verbose flag' {
    workspace
    tsconfig
    ts_project --src "source.ts"
    echo "export const f = 1;" > source.ts
    run bazel build :foo
    assert_success
    run cat $(bazel info output_base)/bazel-workers/worker-1-TsProject.log
    assert_output -p "# Beginning new work" "# Finished the work"  "creating a new worker with the key"
}


@test 'should dump traces' {
    workspace
    tsconfig
    trace=$(mktemp -d)
    ts_project --src "source.ts" --arg --generateTrace $trace
    echo "export const f = 1;" > source.ts
    run bazel build :foo
    assert_success
    run ls $trace
    assert_output -p "trace." "types." "-1.json"
}