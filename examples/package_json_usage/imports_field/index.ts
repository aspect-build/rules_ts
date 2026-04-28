// `#utils` is a Node.js subpath import, defined in the sibling package.json's
// `"imports"` field. TypeScript (under `module: "nodenext"`) reads that map
// during compilation and resolves the specifier to ./utils.js — and from
// there to ./utils.ts for type information. If tsc doesn't see the local
// package.json (which carries this map through ts_config.deps), this import
// fails with TS2307 "Cannot find module '#utils'".
import { greeting } from "#utils";

export const message: string = greeting;
