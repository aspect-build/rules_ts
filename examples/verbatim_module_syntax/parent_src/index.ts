// Same scenario as ../colocated, but the tsconfig.json comes from the parent
// package via `ts_config(src = "//.../verbatim_module_syntax:tsconfig.json")`,
// while the package.json that flips this file to ESM is local and propagated
// through the same ts_config's `deps`.
export const greeting: string = "hello";
