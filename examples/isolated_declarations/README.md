# TypeScript isolated declarations

When the `isolated_declarations` compiler option is used, it ensures that a declarations file `.d.ts` can be produced from a single source file at a time.

See https://devblogs.microsoft.com/typescript/announcing-typescript-5-5/#isolated-declarations
in particular, the section "Use-case: Parallel Declaration Emit and Parallel Checking"
which this example is based on.

In this example, both `backend` and `frontend` packages depend on `core`, however they could be type-checked in parallel
before `core` has produced any declarationEmit.

See [/docs/performance.md](/docs/performance.md) for more information on how to use isolated modules to speed up typechecking.
