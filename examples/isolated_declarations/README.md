# TypeScript isolated declarations

When the `isolated_declarations` flag is used, it ensures that a declarations file `.d.ts` can be produced from a single source file at a time.

See https://devblogs.microsoft.com/typescript/announcing-typescript-5-5/#isolated-declarations
in particular, the section "Use-case: Parallel Declaration Emit and Parallel Checking"
which this example is based on.

In this example, both `backend` and `frontend` packages depend on `core`, however they could be type-checked in parallel
before `core` has produced any declarationEmit.

This doesn't make anything faster yet.
Follow https://github.com/aspect-build/rules_ts/issues/374 for updates on performance improvements to the Bazel action graph.
