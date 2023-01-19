load "common.bats"

setup() {
    cd $BATS_FILE_TMPDIR
}

teardown() {
    bazel shutdown
    rm -rf $BATS_FILE_TMPDIR/*
}

@test 'should emit sourcemaps correctly' {
    workspace
    tsconfig --source-map
    ts_project --src "source.ts" --source-map
    echo 'const t: string = "sourcemaps";' > source.ts 
    run bazel build :foo
    assert_success
    run cat bazel-bin/source.js.map
    assert_success
    assert_output -p '{"version":3,"file":"source.js","sourceRoot":"./","sources":["source.ts"],"names":[],"mappings":"AAAA,IAAM,CAAC,GAAW,YAAY,CAAC"}'
}
