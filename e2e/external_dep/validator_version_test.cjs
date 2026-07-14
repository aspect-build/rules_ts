'use strict'

const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { join } = require('node:path')

const packageJson = JSON.parse(
    readFileSync(join(process.argv[2], 'package.json'), 'utf8')
)
assert.equal(packageJson.name, 'typescript')
assert.equal(packageJson.version, '6.0.2')
