// `import.meta` is an ESM-only language construct. Under `module: "nodenext"`
// TypeScript decides whether this .ts file is ESM or CommonJS by reading the
// nearest package.json's "type" field, so without `"type": "module"` next to
// this file the line below errors with TS1470 ("'import.meta' is not allowed
// in files which will build into CommonJS output").
//
// The sibling package.json reaches the tsc sandbox via ts_config(deps=...).
export const sourceUrl: string = import.meta.url;
