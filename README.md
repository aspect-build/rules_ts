# Bazel rules for TypeScript

> [!NOTE]
> This repository uses the [Aspect CLI](https://github.com/aspect-build/aspect-cli) for CI and local development.
> See the [docs](https://docs.aspect.build/cli/overview) and [install instructions](https://docs.aspect.build/cli/install) to get started.

This is the canonical ruleset for using Bazel with TypeScript, based on
<https://github.com/aspect-build/rules_js>.

Many companies are successfully building with rules_ts. If you're getting value from the project, please let us know! Just comment on our [Adoption Discussion](https://github.com/aspect-build/rules_js/discussions/1000).

rules_ts is just a part of what Aspect provides:

-   _Need help?_ This ruleset has support provided by https://aspect.build/services.
-   See our other Bazel rules, especially those built for rules_js, linked from <https://github.com/aspect-build>

## Installation

Follow instructions from the release you wish to use:
<https://github.com/aspect-build/rules_ts/releases>

## Migrating from aspect_rules_ts

Starting with version 4.0.0, this module is published to the Bazel Central Registry as `rules_ts`
instead of `aspect_rules_ts`. Versions 3.x and earlier remain available under the old name.

The quickest way to migrate is to keep the old repository name, so existing `load()` statements and
`--@aspect_rules_ts//ts:...` flags keep working unchanged:

```starlark
bazel_dep(name = "rules_ts", version = "4.0.0", repo_name = "aspect_rules_ts")
```

Alternatively, depend on `bazel_dep(name = "rules_ts", version = "4.0.0")` and replace
`@aspect_rules_ts` with `@rules_ts` in your `MODULE.bazel`, BUILD, `.bzl` and `.bazelrc` files.

Note that if one of your dependencies still depends on `aspect_rules_ts`, Bazel treats it as a separate
module: it has its own flags and its own `typescript` extension, independent of `rules_ts`.

## Examples

There are a number of examples in [the examples/ folder](https://github.com/aspect-build/rules_ts/tree/main/examples) and
larger examples in the [bazel-examples repository](https://github.com/aspect-build/bazel-examples) using rules_ts such as
[jest](https://github.com/aspect-build/bazel-examples/tree/main/jest), [react](https://github.com/aspect-build/bazel-examples/tree/main/react-cra),
[angular](https://github.com/aspect-build/bazel-examples/tree/main/angular).

If you'd like an example added, you can fund a [Feature Request](https://github.com/aspect-build/rules_ts/issues/new/choose).

## Usage

See the API documentation in [the docs/ folder](https://github.com/aspect-build/rules_ts/tree/main/docs).

### From a BUILD file

The most common use is with the [`ts_project` macro](./docs/rules.md#ts_project) which invokes a
transpiler you configure to transform source files like `.ts` files into outputs such as `.js` and `.js.map`,
and the [`tsc` CLI](https://www.typescriptlang.org/docs/handbook/compiler-options.html) to type-check
the program and produce `.d.ts` files.

### In a macro

Many organizations set default values, so it's common to write a [macro] to wrap `ts_project`, then
ensure that your developers load your macro rather than loading from `@rules_ts` directly.

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
