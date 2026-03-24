import data from './data.json'
import pkg from './package.json'
export const a: string = 'hello' + JSON.stringify(data) + JSON.stringify(pkg)
