# Transpiling TypeScript to JavaScript

The TypeScript compiler `tsc` can perform type-checking, transpilation to JavaScript, or both.
Type-checking is typically slow, and is really only possible with TypeScript, not with alternative tools.
Transpilation is mostly "erase the type syntax" and can be done well by a variety of tools.

`ts_project` allows us to split the work, with the following design goals:

- The user should only need a single BUILD.bazel declaration: "these are my TypeScript sources and their dependencies".
- Most developers have a working TypeScript Language Service in their editor, so they got type hinting before they ran `bazel`.
- Development activities which rely only on runtime code, like running tests or manually verifying behavior in a devserver, should not need to wait on type-checking.
- Type-checking still needs to be verified before checking in the code, but only needs to be as fast as a typical test.

Read more: https://blog.aspect.build/typescript-speedup

## ts_project#transpiler

The `transpiler` attribute of `ts_project` lets you select which tool produces the JavaScript outputs.
Starting in rules_ts 2.0, we require you to select one of these, as there is no good default for all users.

### [SWC](http://swc.rs) (recommended)

SWC is a fast transpiler, and the authors of rules_ts recommend using it.
This option results in the fastest development round-trip time, however it may have subtle
compatibility issues due to producing different JavaScript output than `tsc`.
See https://github.com/aspect-build/rules_ts/discussions/398 for known issues.

To switch to SWC, follow these steps:

1. Install a [recent release of rules_swc](https://github.com/aspect-build/rules_swc/releases)
2. Load `swc`. You can automate this by running:

    ```
    npx @bazel/buildozer 'fix movePackageToTop' //...:__pkg__
    npx @bazel/buildozer 'new_load @aspect_rules_swc//swc:defs.bzl swc' //...:__pkg__
    ```

3. In the simplest case you can skip passing attributes to swc (such as an `.swcrc` file).
   You can update your `ts_project` rules with this command:

    ```
    npx @bazel/buildozer 'set transpiler swc' //...:%ts_project
    ```

4. However, most codebases do rely on configuration options for SWC.
   First, [Synchronize settings with tsconfig.json](https://github.com/aspect-build/rules_swc/blob/main/docs/tsconfig.md) to get an `.swcrc` file,
   then use a pattern like the following to pass this option to `swc`:

        load("@aspect_rules_swc//swc:defs.bzl", "swc")
        load("@bazel_skylib//lib:partial.bzl", "partial")
    
        ts_project(
            ...
            transpiler = partial.make(swc, swcrc = "//:.swcrc"),
        )

6. Cleanup unused load statements:

    ```
    npx @bazel/buildozer 'fix unusedLoads' //...:__pkg__
    ```

### TypeScript [tsc](https://www.typescriptlang.org/docs/handbook/compiler-options.html)

`tsc` can do transpiling along with type-checking.
This is the simplest configuration without additional dependencies. However, it's also the slowest.

> Note that rules_ts used to recommend a "Persistent Worker" mode to keep the `tsc` process running
> as a background daemon, however this introduces correctness issues in the build and is no longer
> recommended. As of rules_ts 2.0, the "Persistent Worker" mode is no longer enabled by default.

To choose this option for a single `ts_project`, set `transpiler = "tsc"`.
You can run `npx @bazel/buildozer 'set transpiler "tsc"' //...:%ts_project` to set the attribute
on all `ts_project` rules.

If you use the default value `transpiler = None`, rules_ts will print an error.
You can simply disable this error for all targets in the build, behaving the same as rules_ts 1.x.
Just add this to `/.bazelrc``:

    # Use "tsc" as the transpiler when ts_project has no `transpiler` set.
    # Bazel 6.4 or greater: 'common' means 'any command that supports this flag'
    common --@aspect_rules_ts//ts:default_to_tsc_transpiler

    # Between Bazel 6.0 and 6.3, you need all of this, to avoid discarding the analysis cache:
    build --@aspect_rules_ts//ts:default_to_tsc_transpiler
    fetch --@aspect_rules_ts//ts:default_to_tsc_transpiler
    query --@aspect_rules_ts//ts:default_to_tsc_transpiler

    # Before Bazel 6.0, only the 'build' and 'fetch' lines work.

### Other Transpilers

The `transpiler` attribute accepts any rule or macro with this signature: `(name, srcs, **kwargs)`
The `**kwargs` attribute propagates the tags, visibility, and testonly attributes from `ts_project`.

See the examples/transpiler directory for a simple example using Babel, or
<https://github.com/aspect-build/bazel-examples/tree/main/ts_project_transpiler>
for a more complete example that also shows usage of SWC.

If you need to pass additional attributes to the transpiler rule such as `out_dir`, you can use a
[partial](https://github.com/bazelbuild/bazel-skylib/blob/main/lib/partial.bzl)
to bind those arguments at the "make site", then pass that partial to this attribute where it will be called with the remaining arguments.

The transpiler rule or macro is responsible for predicting and declaring outputs.
If you want to pre-declare the outputs (so that they can be addressed by a Bazel label, like `//path/to:index.js`)
then you should use a macro which calculates the predicted outputs and supplies them to a `ctx.attr.outputs` attribute
on the rule.

You may want to create a `ts_project` macro within your repository where your choice is setup,
then `load()` from your own macro rather than from `@aspect_rules_ts`.

## Macro expansion

When `no_emit`, `transpiler` or `declaration_transpiler` is set, then the `ts_project` macro expands to these targets:

- `[name]` - the default target which can be included in the `deps` of downstream rules.
    Note that it will successfully build *even if there are typecheck failures* because invoking `tsc` is not needed to produce the default outputs.
    This is considered a feature, as it allows you to have a faster development mode where type-checking is not on the critical path.
- `[name]_types` - provides typings (`.d.ts` files) as the default outputs.
    This target is not created if `no_emit` is set.
- `[name]_typecheck` - provides default outputs asserting type-checking has been run.
    Building this target always causes the typechecker to run.
- `[name]_typecheck_test` - a [`build_test`] target which simply depends on the `[name]_typecheck` target.
    This ensures that typechecking will be run under `bazel test` with [`--build_tests_only`].
-  Any additional target(s) the custom transpiler rule/macro produces.
    (For example, some rules produce one target per TypeScript input file.)


[`build_test`]: https://github.com/bazelbuild/bazel-skylib/blob/main/rules/build_test.bzl
[`--build_tests_only`]: https://docs.bazel.build/versions/main/user-manual.html#flag--build_tests_only
