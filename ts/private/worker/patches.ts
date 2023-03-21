const ts = require('typescript');

// workaround for the issue introduced in https://github.com/microsoft/TypeScript/pull/42095
if (Array.isArray(ts["ignoredPaths"])) {
    ts["ignoredPaths"] = ts["ignoredPaths"].filter(ignoredPath => ignoredPath != "/node_modules/.")
}