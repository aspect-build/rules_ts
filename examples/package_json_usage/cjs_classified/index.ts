// No sibling package.json reaches tsc in this build (see BUILD.bazel).
// Under `module: "nodenext"` + `verbatimModuleSyntax: true`, TypeScript
// therefore classifies this file as CommonJS, and ESM-only language
// constructs are rejected. Each directive below asserts an expected error.

// @ts-expect-error TS1287 — a top-level `export` is rejected in a
// CJS-classified module when verbatimModuleSyntax is on.
export const greeting: string = "hello";

// @ts-expect-error TS1470 — `import.meta` is not allowed in files that
// will build into CommonJS output.
export const sourceUrl: string = import.meta.url;
