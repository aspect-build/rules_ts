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
        [`at Object.<anonymous> (source_map_support/test/a.ts:2:19)`]
    )
    assert.deepEqual(
        frames.filter((f) => f.includes('source_map_support/test/b')),
        [`at foo (source_map_support/test/b.ts:2:9)`]
    )
}
