# TypeScript isolated declarations

When the `isolated_declarations` flag is used, it allows Bazel's typechecking actions to run in parallel.

See https://devblogs.microsoft.com/typescript/announcing-typescript-5-5/#isolated-declarations
in particular, the section "Use-case: Parallel Declaration Emit and Parallel Checking"
which this example is based on.

In this example, both `backend` and `frontend` packages depend on `core`, however they can be type-checked in parallel
before `core` has produced any declarationEmit.
