// Asserts packages containing non-compiling ts

const a = require('@myorg/lib_nocompile')
const b = require('@myorg/lib_nocompile_linked')

console.log('loaded non-compiling dependencies', a, b)
