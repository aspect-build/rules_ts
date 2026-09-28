import { Foo } from 'identity-lib'
import { Foo as RelativeFoo } from '../lib/index'

export const foo: Foo = new RelativeFoo()
