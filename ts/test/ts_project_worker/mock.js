const mod = require('node:module');
const path = require("node:path");

module.exports = function mock(name, exports) {
    const p = path.resolve(name);
    require.cache[p] = {
        id: name,
        file: p,
        loaded: true,
        exports: exports
    };
    const realres = mod._resolveFilename;
    mod._resolveFilename = function (request, parent) {
        if (request == name) {
            return p;
        }
        return realres(request, parent);
    };
}
