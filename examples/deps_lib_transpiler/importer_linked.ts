import { b, format } from '@myorg/deps_lib_transpiler'

export const a: string = `number: 1, date: ${format(
    new Date(2014, 1, 11),
    'MM/dd/YYYY'
)}`

console.log(a, b)
