import num from '@myorg/js_lib'
import num2 from '@myorg/js_lib_pkg'
import { A } from '@myorg/dts_lib'
import { format } from 'date-fns'

export const a: A = 123
export const b: string = `number: ${num}, date: ${format(
    new Date(2014, 1, 11),
    'MM/dd/YYYY'
)}`
export const c: string = `number: ${num2}`

console.log(a, b, c)
