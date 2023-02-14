try {
  require('./b')()
} catch (e) {
  const assert = require('assert')
  const frames = e.stack
    .split('\n')
    .slice(1)
    .map((s) => s.trim())
  assert.deepEqual(
    frames.filter((f) => f.includes('source_map_support/test/a')),
    [`at Object.<anonymous> (examples/source_map_support/test/a.ts:2:17)`],
  )
  assert.deepEqual(
    frames.filter((f) => f.includes('source_map_support/test/b')),
    [`at foo (examples/source_map_support/test/b.ts:2:9)`],
  )
}
