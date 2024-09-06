load "common.bats"

setup() {
    cd $BATS_FILE_TMPDIR
}

teardown() {
    bazel shutdown
    rm -rf $BATS_FILE_TMPDIR/*
}

# bats test_tags=synthetic_outdir
@test 'should invalidate transitive sources that reside in a subpackage.' {
    mkdir -p ./apps/triad/pivot
    mkdir -p ./apps/triad/vibe
    workspace

    # js_library pivot
    echo "export declare function name(): string;" >./apps/triad/pivot/index.d.ts
    echo "module.exports = { name: function () { return 'pivot'; } };" >./apps/triad/pivot/index.js
    js_library --path ./apps/triad/pivot --name pivot --src "index.d.ts" --src "index.js"

    # ts_project vibe
    echo "export function name(): string { return 'vibe'; }" >./apps/triad/vibe/index.ts
    tsconfig --path ./apps/triad/vibe --declaration
    ts_project --path ./apps/triad/vibe --name vibe --declaration --src "index.ts"

    # ts_project triad
    cat >./apps/triad/main.ts <<EOF
import { name as vibeName } from './vibe';
import { name as pivotName } from './pivot';

console.log(vibeName());
console.log(pivotName());
EOF
    ts_project --path ./apps/triad --name triad --declaration --src "main.ts"
    tsconfig --path ./apps/triad --declaration

    run bazel build //apps/triad
    assert_failure
    assert_output -p "apps/triad/main.ts(1,34): error TS2307: Cannot find module './vibe' or its corresponding type declarations."
    assert_output -p "apps/triad/main.ts(2,35): error TS2307: Cannot find module './pivot' or its corresponding type declarations."

    ts_project --path ./apps/triad --name triad --declaration --src "main.ts" --dep "//apps/triad/pivot"
    run bazel build //apps/triad
    assert_failure
    assert_output -p "apps/triad/main.ts(1,34): error TS2307: Cannot find module './vibe' or its corresponding type declarations."
    refute_output -p "apps/triad/main.ts(2,35): error TS2307: Cannot find module './pivot' or its corresponding type declarations."

    ts_project --path ./apps/triad --name triad --declaration --src "main.ts" --dep "//apps/triad/vibe"
    run bazel build //apps/triad
    assert_failure
    assert_output -p "apps/triad/main.ts(2,35): error TS2307: Cannot find module './pivot' or its corresponding type declarations."
    refute_output -p "apps/triad/main.ts(1,34): error TS2307: Cannot find module './vibe' or its corresponding type declarations."

    ts_project --path ./apps/triad --name triad --declaration --src "main.ts" --dep "//apps/triad/pivot" --dep "//apps/triad/vibe"
    run bazel build //apps/triad
    assert_success
    refute_output -p "apps/triad/main.ts(2,35): error TS2307: Cannot find module './pivot' or its corresponding type declarations."
    refute_output -p "apps/triad/main.ts(1,34): error TS2307: Cannot find module './vibe' or its corresponding type declarations."
}

@test 'should invalidate 1p deps correctly' {
    workspace
    mkdir ./feature1 ./feature2

    echo "export function name1(): string { return 'feature1'; }" >./feature1/index.ts
    tsconfig --path ./feature1 --declaration
    ts_project --path ./feature1 --name feature1 --declaration --src "index.ts"

    echo "export function name2(): string { return 'feature2'; }" >./feature2/index.ts
    tsconfig --path ./feature2 --declaration
    ts_project --path ./feature2 --name feature2 --declaration --src "index.ts"

    echo "export * from './feature1'; export * from './feature2'" >index.ts
    tsconfig

    ts_project --src "index.ts"
    run bazel build :foo
    assert_failure
    assert_output -p "index.ts(1,15): error TS2307: Cannot find module './feature1' or its corresponding type declarations."
    assert_output -p "index.ts(1,43): error TS2307: Cannot find module './feature2' or its corresponding type declarations."

    ts_project --src "index.ts" --dep "//feature1"
    run bazel build :foo
    assert_failure
    refute_output -p "index.ts(1,15): error TS2307: Cannot find module './feature1' or its corresponding type declarations."
    assert_output -p "index.ts(1,43): error TS2307: Cannot find module './feature2' or its corresponding type declarations."

    ts_project --src "index.ts" --dep "//feature2"
    run bazel build :foo
    assert_failure
    assert_output -p "index.ts(1,15): error TS2307: Cannot find module './feature1' or its corresponding type declarations."
    refute_output -p "index.ts(1,43): error TS2307: Cannot find module './feature2' or its corresponding type declarations."

    ts_project --src "index.ts" --dep "//feature1" --dep "//feature2"

    run bazel build :foo
    assert_success
}

@test 'should not read a file thats been removed from srcs' {
    workspace
    tsconfig
    echo "const t = true;" >default.ts

    for i in $(seq 0 10); do
        echo "const a = $i" >"source_$i.ts"
        ts_project --src default.ts --src "source_$i.ts"
        run bazel build :foo
        assert_success

        rm "source_$i.ts"
        ts_project --src default.ts
        run bazel build :foo
        assert_success
    done
}

@test 'should handle tsconfig change, file addition and removal in one batch' {
    workspace
    tsconfig
    echo "export class T{ get t(){ return 'test' } }" >default.ts
    ts_project --src default.ts

    run bazel build :foo
    assert_success
    run cat bazel-bin/default.js
    assert_output -p "get t() { return 'test'; }"

    tsconfig --target ES5
    rm default.ts
    echo "export class T{ get t(){ return 'test' } }" >new.ts

    ts_project --src new.ts
    run bazel build :foo
    assert_success
    run cat bazel-bin/new.js
    refute_output -p "get t() { return 'test'; }" 'var T = /** @class */ (function () {" "Object.defineProperty(T.prototype, "t", {'
}
