export const name = `fancy_feature`

export const sub = import('./sub/index.js').then((s) => s.name)
