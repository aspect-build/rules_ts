import { sayHello } from './'

let captured: string = ''
console.log = (s: string) => (captured = s)
sayHello(' world')

if (captured !== 'hello world') {
    console.error("Expected output to be 'hello world'")
    process.exit(1)
}
