# Bazel rules for ts

High-performance alternative to the `@bazel/typescript` npm package, based on
https://github.com/aspect-build/rules_js.

The `ts_project` rule here is identical to the one in rules_nodejs, making it easy to migrate.

Since rules_js always runs tools from the bazel-out tree, rules_ts naturally fixes the usability bugs with rules_nodejs.

- Freely mix generated `*.ts` and `tsconfig.json` files in the bazel-out tree with source files
- Fixes the need for any `rootDirs` settings in `tsconfig.json` as reported in https://github.com/microsoft/TypeScript/issues/37378
- "worker mode" for `ts_project` now shares workers across all targets, rather than requiring one worker pool per target

## Installation

From the release you wish to use:
<https://github.com/aspect-build/rules_ts/releases>
copy the WORKSPACE snippet into your `WORKSPACE` file.

Please note that rules_ts does not work with `--worker_sandboxing`.
