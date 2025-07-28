import type { join } from 'node:path'
import type { IntersectionType } from '../core'

// Example object of IntersectionType
const myObject: IntersectionType = {
    a: 42,
    b: 'backend',
    c: true,
}

const myJoin: typeof join = (p1: string, p2: string) => p1 + p2

console.log(myObject)
console.log(myJoin('Hello, ', 'world!'))
