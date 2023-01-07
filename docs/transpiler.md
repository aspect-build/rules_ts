# Transpiling TypeScript to JavaScript

The TypeScript compiler `tsc` can perform type-checking, transpilation to JavaScript, or both.
Type-checking can be slow, and is really only possible with TypeScript, not with alternative tools, because the type system is so rich that writing a correct checker is a massive undertaking.

Transpilation is mostly "erase the type syntax" and can be done well by a variety of tools.
`tsc` is regarded as the slowest option for transpilation, so it makes sense to divide the work between two tools. 

`ts_project` supports this with the following design goals:

- The user should only need a single BUILD.bazel declaration of "this is my TypeScript code and its dependencies".
- Most developers have a working TypeScript Language Service in their editor, so they got type hinting before they ran the build tool.
- Development activities which rely only on runtime code, like running tests or manually verifying behavior in a devserver, should not need to wait on type-checking.
- Type-checking still needs to be verified before checking in the code, but only needs to be as fast as a typical test.

Read more: https://blog.aspect.dev/typescript-speedup

## ts_project#transpiler

The `transpiler` attribute of `ts_project` lets you select which tool produces the JavaScript outputs.
By default, we use [SWC](https://swc.rs/).

Using a value of `None` means that `tsc` should do transpiling along with type-checking. This is the simplest configuration without additional dependencies, however as noted above, it's also the slowest.

The `transpiler` attribute accepts a rule or macro with this signature:
`name, srcs, **kwargs`
where the `**kwargs` attribute propagates the tags, visibility, and testonly attributes from `ts_project`.

If you need to pass additional attributes to the transpiler rule such as `out_dir`, you can use a
[partial](https://github.com/bazelbuild/bazel-skylib/blob/main/lib/partial.bzl)
to bind those arguments at the "make site", then pass that partial to this attribute where it will be called with the remaining arguments.
The transpiler rule or macro is responsible for predicting and declaring outputs.
If you want to pre-declare the outputs (so that they can be addressed by a Bazel label, like `//path/to:index.js`)
then you should use a macro which calculates the predicted outputs and supplies them to a `ctx.attr.outputs` attribute
on the rule.
See the examples/transpiler directory for a simple example using Babel, or
<https://github.com/aspect-build/bazel-examples/tree/main/ts_project_transpiler>
for a more complete example that also shows usage of SWC.

## Macro expansion

When a transpiler other than `tsc` is used, then the `ts_project` macro expands to these targets:

- `[name]` - the default target which can be included in the `deps` of downstream rules.
    Note that it will successfully build *even if there are typecheck failures* because invoking `tsc` is not needed to produce the default outputs.
    This is considered a feature, as it allows you to have a faster development mode where type-checking is not on the critical path.
- `[name]_typecheck` - provides typings (`.d.ts` files) as the default output.
    Building this target always causes the typechecker to run.
- `[name]_typecheck_test` - a [`build_test`] target which simply depends on the `[name]_typecheck` target.
    This ensures that typechecking will be run under `bazel test` with [`--build_tests_only`].
- `[name]_typings` - internal target which runs the binary from the `tsc` attribute
-  Any additional target(s) the custom transpiler rule/macro produces.
    (For example, ome rules produce one target per TypeScript input file.)


[`build_test`]: https://github.com/bazelbuild/bazel-skylib/blob/main/rules/build_test.bzl
[`--build_tests_only`]: https://docs.bazel.build/versions/main/user-manual.html#flag--build_tests_only