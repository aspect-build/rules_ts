load "common.bats"

setup() {
    cd $BATS_FILE_TMPDIR
}

teardown() {
    bazel shutdown
    rm -rf $BATS_FILE_TMPDIR/*
}

@test 'should report missing third-party deps' {
    run pnpm add @nestjs/core@9.0.8 @nestjs/common@9.0.8 rxjs@7.1.0 @types/node@18.11.9 --lockfile-only

    workspace --npm-translate-lock
    tsconfig

    echo 'export * as core from "@nestjs/core"' > source.ts

    ts_project -l -s "source.ts" -d ":node_modules/@types/node"
    run bazel build :foo
    assert_failure
    assert_output -p "source.ts(1,23): error TS2307: Cannot find module '@nestjs/core' or its corresponding type declarations."

    ts_project -l -s "source.ts" -d ":node_modules/@nestjs/core" -d ":node_modules/@types/node"
    run bazel build :foo
    assert_success

    ts_project -l -s "source.ts" -d ":node_modules/@nestjs/core"
    run bazel build :foo
    assert_failure 
    assert_output -p "error TS2688: Cannot find type definition file for 'node'." "error TS2503: Cannot find namespace 'NodeJS'."

    ts_project -l -s "source.ts" -d ":node_modules/@nestjs/core" -d ":node_modules/@types/node"
    run bazel build :foo
    assert_success
}