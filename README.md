# Bazel rules for TypeScript

This is the canonical ruleset for using Bazel with TypeScript, based on
<https://github.com/aspect-build/rules_js>.

Many companies are successfully building with rules_ts. If you're getting value from the project, please let us know! Just comment on our [Adoption Discussion](https://github.com/aspect-build/rules_js/discussions/1000).

This is a high-performance alternative to the `@bazel/typescript` npm package from rules_nodejs.
The `ts_project` rule here is identical to the one in rules_nodejs, making it easy to migrate.
Since rules_js always runs tools from the bazel-out tree, rules_ts naturally fixes most usability bugs with rules_nodejs:

-   Freely mix generated `*.ts` and `tsconfig.json` files in the bazel-out tree with source files
-   Fixes the need for any `rootDirs` settings in `tsconfig.json` as reported in https://github.com/microsoft/TypeScript/issues/37378
-   "worker mode" for `ts_project` now shares workers across all targets, rather than requiring one worker pool per target

rules_ts is just a part of what Aspect provides:

-   _Need help?_ This ruleset has support provided by https://aspect.build/services.
-   See our other Bazel rules, especially those built for rules_js, linked from <https://github.com/aspect-build>

## Installation

Follow instructions from the release you wish to use:
<https://github.com/aspect-build/rules_ts/releases>

## Examples

There are a number of examples in [the examples/ folder](https://github.com/aspect-build/rules_ts/tree/main/examples) and
larger examples in the [bazel-examples repository](https://github.com/aspect-build/bazel-examples) using rules_ts such as
[jest](https://github.com/aspect-build/bazel-examples/tree/main/jest), [react](https://github.com/aspect-build/bazel-examples/tree/main/react-cra),
[angular](https://github.com/aspect-build/bazel-examples/tree/main/angular).

If you'd like an example added, you can fund a [Feature Request](https://github.com/aspect-build/rules_ts/issues/new/choose).

## Usage

See the API documentation at https://registry.bazel.build/docs/aspect_rules_ts.

### From a BUILD file

The most common use is with the `ts_project` macro which invokes a
transpiler you configure to transform source files like `.ts` files into outputs such as `.js` and `.js.map`,
and the [`tsc` CLI](https://www.typescriptlang.org/docs/handbook/compiler-options.html) to type-check
the program and produce `.d.ts` files.

### In a macro

Many organizations set default values, so it's common to write a [macro] to wrap `ts_project`, then
ensure that your developers load your macro rather than loading from `@aspect_rules_ts` directly.

[macro]: https://bazel.build/extending/macros

### BUILD file generation

Aspect provides a TypeScript BUILD file generator as part of the [Aspect CLI](https://aspect.build/cli).
Run `aspect configure` to create or update `BUILD.bazel` files as you edit TypeScript sources.
See <https://docs.aspect.build/cli/commands/aspect_configure>.

### Advanced: custom rules

If you know how to write Bazel rules, you might find that `ts_project` doesn't do what you want.

One way to customize it is to peel off one layer of indirection, by calling the `ts_project_rule`
directly. This bypasses our default setting logic, and also the validation program which checks that
ts_project attributes are well-formed.

You can also write a custom rule from scratch. We expose helper functions from /ts/private in this
repo. Be aware that these are not a public API, so you may have to account for breaking changes
which aren't subject to our usual semver policy.

# Telemetry & privacy policy

This ruleset collects limited usage data via [`tools_telemetry`](https://github.com/aspect-build/tools_telemetry), which is reported to Aspect Build Inc and governed by our [privacy policy](https://www.aspect.build/privacy-policy).
