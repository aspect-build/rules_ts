"The TypeScript compiler selected by //:typescript"

TSC = select({
    "//:typescript_7": "@npm_typescript7//:tsc",
    "//conditions:default": "@npm_typescript//:tsc",
})

VALIDATOR = select({
    "//:typescript_7": "@npm_typescript7//:validator",
    "//conditions:default": "@npm_typescript//:validator",
})
