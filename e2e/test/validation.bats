load "common.bats"

setup() {
    cd $BATS_FILE_TMPDIR
}

teardown() {
    bazel shutdown
    rm -rf $BATS_FILE_TMPDIR/*
}


@test 'When tsc is only used for type-checking with a type-error, should pass when validations are disabled' {
    workspace

    echo "export const a: string = 1;" > ./source.ts
    tsconfig --declaration
    ts_project --transpiler-mock --declaration --src "source.ts"

    run bazel build :foo --norun_validations
    assert_success
    run cat bazel-bin/source.js
    assert_success
    # Mock transpiler just copies source input to output
    assert_output -p 'export const a: string = 1;'
}

@test 'When tsc is only used for type-checking with a type-error, should fail when validations are enabled' {
    workspace

    echo "export const a: string = 1;" > ./source.ts
    tsconfig --no-emit
    ts_project --no-emit --src "source.ts"
    
    run bazel build :foo --run_validations
    assert_failure
    assert_output -p "error TS2322: Type 'number' is not assignable to type 'string'"
}
