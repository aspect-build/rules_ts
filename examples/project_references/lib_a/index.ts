export const a: string = 'hello'

// Repro rules_nodejs#2044
import { DecoratorsPluginOptions } from '@babel/parser'
export const o: DecoratorsPluginOptions = {}
