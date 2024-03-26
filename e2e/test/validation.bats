load "common.bats"

setup() {
    cd $BATS_FILE_TMPDIR
}

teardown() {
    bazel shutdown
    rm -rf $BATS_FILE_TMPDIR/*
}


@test 'When tsc is only used for type-checking, should only fail when validations are enabled' {
    workspace

    load_mock_transpiler
    echo "export const a: string = 1;" > ./source.ts
    tsconfig 
    ts_project --mockTranspiler --src "source.ts"

    run bazel build :foo --norun_validations
    assert_failure
    
    run bazel build :foo --run_validations
    assert_failure
}