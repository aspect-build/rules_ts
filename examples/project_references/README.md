# TypeScript Project References

TypeScript has its own feature for breaking up a large TS program into multiple compilation units:

> Project references are a new feature in TypeScript 3.0 that allow you to structure your TypeScript programs into smaller pieces.
> By doing this, you can greatly improve build times, enforce logical separation between components, and organize your code in new and better ways.
> We’re also introducing a new mode for tsc, the --build flag, that works hand in hand with project references to enable faster TypeScript builds.

See documentation: https://www.typescriptlang.org/docs/handbook/project-references.html

This works with rules_ts, as this example demonstrates.
However, Project References don't provide any benefit in Bazel, since we already knew how to compile
projects independently and have them reference each other.
The reason you'd set it up this way is to allow `tsc --build` to work outside of Bazel, allowing
both legacy and Bazel workflows to coexist in the same codebase.

## Known issues

TypeScript writes a .tsbuildinfo output file for composite projects. This is intended to make a
subsequent compilation of that project faster, by loading that file and reusing information from
a previous execution of `tsc` to enable incremental builds.
Under Bazel, the `.tsbuildinfo` file is produced, but the result is ignored, because Bazel does not
permit the output of an action to be reused as an input to a subsequent spawn of the same action,
as that would be non-hermetic.

## Dependency graph

`app` depends on `lib_b` which depends on `lib_a`. Each one is marked with `composite = True` so
TypeScript knows to look for the referenced project by resolving to the other `tsconfig.json` file.
