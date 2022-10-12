// This import ought to be disallowed by a "strict dependencies" feature.
// We didn't tell TypeScript that app depends on lib_a, so the import should not resolve.
// In theory, we could make a custom compiler just for Bazel (like ts_library from google3)
// to implement a strict dependencies feature, but the rules_ts philosophy is to be a thin starlark
// wrapper around TypeScript's tsc.
// See https://github.com/microsoft/TypeScript/issues/36743
import { a } from '../lib_a'
import { sayHello } from '../lib_b'

sayHello('world')
console.error(a)
