load "common.bats"

setup() {
    cd $BATS_FILE_TMPDIR
}

teardown() {
    bazel shutdown
    rm -rf $BATS_FILE_TMPDIR/*
}

@test 'should build successfully and not print the error message with --strategy=sandboxed' {
    workspace
    tsconfig

    ts_project --src "source.ts"
    echo 'const t: string = "sandboxed";' > source.ts 
    run bazel build :foo --strategy=TsProject=sandboxed
    assert_success
    refute_output -p "WARNING: Running" "TsProject" "as a standalone process" "From Compiling TypeScript project"
}


@test 'should build successfully and print the error message with --strategy=local' {
    workspace
    tsconfig

    ts_project --src "source.ts"
    echo 'const t: string = "local";' > source.ts 
    run bazel build :foo --strategy=TsProject=local
    assert_success
    assert_output -p "WARNING: Running" "TsProject" "as a standalone process" "From Compiling TypeScript project"
}
