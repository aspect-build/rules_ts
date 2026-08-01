# deprecated_ext

Backward-compatibility e2e test for the deprecated bzlmod module extension surface.

Every other workspace in this repo uses the current API:

```starlark
typescript = use_extension("@aspect_rules_ts//ts:extensions.bzl", "typescript")
typescript.deps(version_from = "//:package.json")
use_repo(typescript, "npm_typescript")
```

This workspace deliberately keeps using the **deprecated** names — the `ext`
extension symbol and the `ts_version` / `ts_version_from` / `ts_integrity` tag
attributes — to prove the compatibility shims still resolve a working
`npm_typescript` repository (while emitting deprecation warnings). The shims are
removed in the next major release.

It also uses the `typescript` extension in the same module, covering a partial
migration: the two symbols are distinct extensions with their own repo namespace,
so their repos coexist (each fetching its own copy of TypeScript) rather than
conflicting.
