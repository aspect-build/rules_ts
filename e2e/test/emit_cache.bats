load "common.bats"

setup() {
    cd $BATS_FILE_TMPDIR
}

teardown() {
    bazel shutdown
    rm -rf $BATS_FILE_TMPDIR/*
}


@test 'should emit .tsbuildinfo' {
    workspace
    mkdir ./a ./b

    echo "export function a(): string { return 'a'; }" > ./a/index.ts
    tsconfig --path ./a --declaration --composite
    ts_project --path ./a --name a --src "index.ts" --declaration --composite

    echo "export function b(): string { return 'b'; }" > ./b/index.ts
    tsconfig --path ./b --declaration --composite
    ts_project --path ./b --name b --src "index.ts" --declaration --composite

    echo "export * from './a'; export * from './b'" > index.ts
    tsconfig --declaration --composite

    ts_project --src "index.ts" --dep "//a" --dep "//b" --declaration --composite
    run bazel build :foo
    assert_success
}