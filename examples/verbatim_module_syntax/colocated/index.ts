// Under `verbatimModuleSyntax: true` + `module: "nodenext"`, this `export`
// statement only type-checks if TypeScript classifies the file as ESM, which
// requires it to find a sibling package.json containing `"type": "module"`.
// The sibling package.json reaches the sandbox via ts_config(deps=...).
export const greeting: string = "hello";
