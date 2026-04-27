// Node.js (and TypeScript under `module: "nodenext"`) lets a package import
// itself by its own `"name"`, with the specifier resolved through the
// `"exports"` map in the same package.json. tsc walks up from this file,
// finds the sibling package.json, matches `"name": "self-reference-example"`,
// reads `"exports"."./greeting" = "./greeting.js"`, and follows that to the
// .ts source for type information. Without the package.json in tsc's
// sandbox, the import fails with TS2307 "Cannot find module 'self-reference-example/greeting'".
import { greeting } from "self-reference-example/greeting";

export const message: string = greeting;
