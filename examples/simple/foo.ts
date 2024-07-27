import num from '@myorg/js_pkg'
import num2 from '@myorg/js_lib'
import { A } from '@myorg/dts_pkg'
import { format } from 'date-fns'

export const a: A = 123
export const b: string = `number: ${num}, date: ${format(
    new Date(2014, 1, 11),
    'MM/dd/YYYY'
)}`
export const c: string = `number: ${num2}`

console.log(a, b, c)
