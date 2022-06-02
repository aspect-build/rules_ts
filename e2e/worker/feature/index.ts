export const name = `fancy_feature`

export const sub = import("./sub").then(s => s.name);