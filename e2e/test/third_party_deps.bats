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

    echo 'export * as core from "@nestjs/core"' >source.ts

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

@test 'should report @types/<pkg> <pkg> pair errors correctly' {
    run pnpm add @types/debug@4.1.7 debug@4.3.4 --lockfile-only

    workspace --npm-translate-lock
    tsconfig --extended-diagnostics --trace-resolution

    echo 'import * as debug from "debug";' >source.ts
    echo 'debug.log("test");' >>source.ts

    ts_project -l -s "source.ts" -d ":node_modules/@types/debug"
    run bazel build :foo
    assert_success
    refute_output -p "Cannot find module 'debug' or its corresponding type declarations."

    ts_project -l -s "source.ts" -d ":node_modules/debug"
    run bazel build :foo
    assert_success
    refute_output -p "Cannot find module 'debug' or its corresponding type declarations."

    # TODO: !!!!A TYPESCRIPT BUG!!!. we correctly report changes for modules but tsc doesn't calculate diagnostics for sources eventhough modules don't exist anymore.
    # think this as if you'd have to do cmd+s to make tsc --watch to reconsider the decision.
    echo " " >>source.ts
    ts_project -l -s "source.ts"
    run bazel build :foo
    assert_failure
    assert_output -p "source.ts(1,24): error TS2307: Cannot find module 'debug' or its corresponding type declarations."
}

@test 'should report new transitive deps correctly and tsc should not ignore it' {
    workspace --npm-translate-lock --noconvenience-symlinks # bazel- symlinks makes pnpm hang
    tsconfig --extended-diagnostics --trace-resolution

    mkdir -p ./features/cool ./features/notcool

    echo "export declare function cool(): import('@feature/notcool').not" >./features/cool/index.d.ts
    js_library -l --path ./features/cool --name cool_lib --src "index.d.ts"
    npm_package --path ./features/cool --name cool --src ":cool_lib"
    echo '{"name": "@feature/cool"}' >./features/cool/package.json

    echo "export declare type not = string" >./features/notcool/index.d.ts
    js_library -l --path ./features/notcool --name notcool_lib --src "index.d.ts"
    npm_package --path ./features/notcool --name notcool --src ":notcool_lib"
    echo '{"name": "@feature/notcool"}' >./features/notcool/package.json

    echo '-packages: ["features/cool", "features/notcool"]' >pnpm-workspace.yaml
    echo '{"dependencies":{"@feature/cool": "workspace:*", "@types/node": "*"}}' >package.json
    run pnpm install --lockfile-only
    assert_success

    echo "import {cool} from '@feature/cool'; export const t: number = cool()" >source.ts
    ts_project -l -s "source.ts" -d ":node_modules/@feature/cool"
    run bazel build :foo --@aspect_rules_ts//ts:supports_workers
    assert_failure
    assert_output -p "node_modules/.aspect_rules_js/@feature+cool@0.0.0/node_modules/@feature/cool/index.d.ts(1,40): error TS2307: Cannot find module '@feature/notcool' or its corresponding type declarations."

    echo '{"dependencies":{"@feature/cool": "workspace:*", "@types/node": "*"}, "pnpm": {"packageExtensions": {"@feature/cool": {"dependencies": {"@feature/notcool": "workspace:*"}}}}}' >package.json
    run pnpm install --lockfile-only
    assert_success
    run bazel build :foo --@aspect_rules_ts//ts:supports_workers
    assert_success
}
