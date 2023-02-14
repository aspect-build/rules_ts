// See defs.bzl for where this is used and what it does.

require('source-map-support/register')

let basePath = process.env.RUNFILES
  ? `${process.env.RUNFILES}/${process.env.JS_BINARY__WORKSPACE}`
  : process.cwd()

if (!basePath.endsWith('/')) {
  basePath = basePath + '/'
}

/*
Before:
    Error: test
        at foo (/private/var/tmp/_bazel_john/67beefda950d56283b98d96980e6e332/execroot/figma/bazel-out/darwin_arm64-fastbuild/bin/bazel/js/test/stack_trace_support.sh.runfiles/figma/bazel/js/test/b.js:2:11)
        at Object.<anonymous> (/private/var/tmp/_bazel_john/67beefda950d56283b98d96980e6e332/execroot/figma/bazel-out/darwin_arm64-fastbuild/bin/bazel/js/test/stack_trace_support.sh.runfiles/figma/bazel/js/test/a.js:4:1)
        ...

After:
    Error: test
        at foo (bazel/js/test/b.ts:2:9)
        at Object.<anonymous> (bazel/js/test/a.ts:5:1)
        ...
*/

const basePathRegex = new RegExp(
  `(at | \\()${basePath
    .replace(/\\/g, '/')
    // Escape regex meta-characters.
    .replace(/[|\\{}()[\]^$+*?.]/g, '\\$&')
    .replace(/-/g, '\\x2d')}`,
  'g',
)

const prepareStackTrace = Error.prepareStackTrace
Error.prepareStackTrace = function (error, stack) {
  return prepareStackTrace(error, stack)
    .split('\n')
    .map((line) => line.replace(basePathRegex, '$1'))
    .join('\n')
}
