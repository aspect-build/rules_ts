import type { IntersectionType } from '../core'
import { MyIntersectingValue } from '../core'

// Example object of IntersectionType
const myObject: IntersectionType = {
    a: 42,
    b: 'frontend',
    c: true,
}

const otherObject = MyIntersectingValue

console.log(myObject, otherObject, myObject === otherObject)
