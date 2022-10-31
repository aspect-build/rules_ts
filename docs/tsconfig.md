# Configuring TypeScript

TypeScript provides "compiler options" which interact with how Bazel builds and type-checks code.

## General guidance

Keep a `tsconfig.json` file at the root of your TypeScript sources tree, as an ancestor of all TypeScript files.
This should have your standard settings that apply to all code in the package or repository.
This ensures that editors agree with rules_ts, and that you have minimal repetition of settings which can get diverged over time.

## Mirroring tsconfig settings

`ts_project` needs to know some of the values from tsconfig.json.
This is so we can mimic the semantics of `tsc` for things like which files are included in the program, and to predict output locations.

These attributes are named as snake-case equivalents of the tsconfig.json settings.
For example, [`outDir`](https://www.typescriptlang.org/tsconfig#outDir) is translated to `out_dir`.

The `ts_project` macro expands to include a validation action, which uses the TypeScript API to load the `tsconfig.json` file (along with any that it `extends`) and compare these values to attributes on the `ts_project` rule.
It produces [buildozer] commands to correct the BUILD.bazel file when they disagree.

[buildozer]: https://github.com/bazelbuild/buildtools/blob/master/buildozer/README.md

## Locations of tsconfig.json files

You can use a single `tsconfig.json` file for a repository.
Since rules_js expects files to appear in the `bazel-out` tree, the common pattern is:

1. In the `BUILD.bazel` file next to `tsconfig.json`, expose it using a `ts_config` rule:

```starlark
load("@aspect_rules_ts//ts:defs.bzl", "ts_config")

ts_config(
    name = "tsconfig",
    src = "tsconfig.json",
    visibility = [":__subpackages__"],
)
```

2. In child packages, set the `tsconfig` attribute of `ts_project` rules in subpackages to point to this rule.

```
load("@aspect_rules_ts//ts:defs.bzl", "ts_config")

ts_project(
    ...
    tsconfig = "//my_root:tsconfig",
)
```

You can also use nested `tsconfig.json` files. Typically you want these to inherit common settings from the parent, so use the [`extends`](https://www.typescriptlang.org/tsconfig#extends) feature in the `tsconfig.json` file. Then you'll need to tell Bazel about this dependency structure, so add a `deps` list to `ts_config` and repeat the files there.

## Inline (generated) tsconfig

The `ts_project#tsconfig` attribute accepts a dictionary.
If supplied, this dictionary is converted into a JSON file.
It should have a top-level `compilerOptions` key, matching the tsconfig file JSON schema.

Since its location differs from `tsconfig.json` in the source tree, and TypeScript
resolves paths in `tsconfig.json` relative to its location, some paths must be
written into the generated file:

- each file in srcs will be converted to a relative path in the `files` section.
- the `extends` attribute will be converted to a relative path

The generated `tsconfig.json` file can be inspected in `bazel-out`.

> Remember that editors need to know some of the tsconfig settings, so if you rely
> exclusively on this approach, you may find that the editor skew affects development.

You can mix-and-match values in the dictionary with attributes.
Values in the dictionary take precedence over those in the attributes,
and conflicts between them are not validated. For example, in

```starlark
ts_project(
    name = "which",
    tsconfig = {
        "compilerOptions": {
            "declaration": True,
            "rootDir": "subdir",
        },
    },
    out_dir = "dist",
    root_dir = "other",
)
```

the value `subdir` will be used by `tsc`, and `other` will be silently ignored.
Both `outDir: dist` and `declaration: true` will be used.

As with any Starlark code, you could define this dictionary in a central location and load it as a symbol into your BUILD.bazel files.
            