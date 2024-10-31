;(typeof globalThis !== 'undefined'
    ? globalThis
    : (window as any)
).myGlobalResult = myGlobalFunction(42)

export {}

// A definition within a .ts file that must be compiled.
declare global {
    const myGlobalResult: string
}
