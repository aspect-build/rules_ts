import num from '@myorg/js_lib'
import { A } from '@myorg/dts_lib'
import { format } from 'date-fns'

export const a: A = 123;
export const b: string = `number: ${num}, date: ${format(
    new Date(2014, 1, 11),
    'MM/dd/YYYY'
)}`

console.log(a, b)
