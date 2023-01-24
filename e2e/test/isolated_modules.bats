load "common.bats"

setup() {
    cd $BATS_FILE_TMPDIR
}

teardown() {
    bazel shutdown
    rm -rf $BATS_FILE_TMPDIR/*
}

@test 'should report errors' {
    workspace
    tsconfig

    echo 'function fn() {}' > nonmodule.ts
    echo 'export type test = string' > lib.ts
    echo 'import {test} from "./lib"; export {test}' > source.ts
    ts_project -s "source.ts" -s "lib.ts" -s "nonmodule.ts"

    run bazel build :foo
    assert_success
    refute_output -p "error"

    tsconfig --isolated-modules
    run bazel build :foo
    assert_failure
    assert_output -p "nonmodule.ts(1,1): error TS1208: 'nonmodule.ts' cannot be compiled under '--isolatedModules' because it is considered a global script file. Add an import, export, or an empty 'export {}' statement to make it a module."
}


@test 'should report errors for 3p deps' {
    run pnpm add @types/node@18.11.9 --lockfile-only

    workspace --npm-translate-lock
    tsconfig --extended-diagnostics

    echo 'import {BigIntStats} from "node:fs"; export {BigIntStats}' > source.ts
    ts_project -l -s "source.ts" -d ":node_modules/@types/node"

    run bazel build :foo
    assert_success
    refute_output -p "error"

    tsconfig --isolated-modules --extended-diagnostics
    echo " " >> source.ts # TODO: figure out why the case above works but not this one.
    run bazel build :foo
 
    assert_failure
    assert_output -p "source.ts(1,46): error TS1205: Re-exporting a type when the '--isolatedModules' flag is provided requires using 'export type'."
    
}