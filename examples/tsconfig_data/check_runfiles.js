// Regression test for https://github.com/aspect-build/rules_ts/issues/190
// Verifies that transitive ts_config deps are available in the runfiles of a
// downstream js_binary/js_test that lists a ts_config target in its data.
const fs = require('fs')
const path = require('path')

// tsconfig.base.json lives in a separate Bazel package (//tsconfig_data/base).
// It is NOT directly listed anywhere in this test's data — it only reaches
// the runfiles through ts_config's deps = ["//tsconfig_data/base:tsconfig_base"].
// If ts_config does not propagate its deps into DefaultInfo.runfiles, this
// file will be absent and the test will fail.
const base = path.join(__dirname, 'base', 'tsconfig.base.json')
if (!fs.existsSync(base)) {
    console.error('tsconfig.base.json not found in runfiles at: ' + base)
    process.exit(1)
}
