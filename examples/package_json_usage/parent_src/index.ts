// Same `import.meta` ESM-only demonstration as ../colocated/index.ts, but
// the tsconfig.json comes from the parent package via
// `ts_config(src = "//package_json_usage:tsconfig")`, while the
// sibling package.json is local and propagated through that same
// ts_config's `deps`.
export const sourceUrl: string = import.meta.url;
