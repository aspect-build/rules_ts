/**
 * This testcase exists to verify assets get propagated correctly. It
 * intentionally does not use `import` or `require` for the generated asset to
 * more closely mimic what a downstream rule (eg. a bundler) would do.
 */
import * as fs from 'fs'
import * as path from 'path'

const data = fs.readFileSync(path.join(__dirname, 'generated.json'))

console.log(__dirname, data)
