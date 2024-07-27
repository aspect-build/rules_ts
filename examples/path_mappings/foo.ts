import num from '@myorg/js_pkg'
import { A } from '@myorg/dts_pkg'

export const a: A = 123
export const b: string = `number: ${num}`

console.log(a, b)
