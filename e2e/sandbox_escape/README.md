# sandbox_escape

Reproductions of TypeScript 7 (`tsgo`) escaping the Bazel sandbox.

Every sandbox input is a symlink into the execroot. When TypeScript 7 resolves a
module through `node_modules` it follows that symlink to its realpath, which is
outside the sandbox in `execroot/.../bazel-bin`. Any further resolution from
there sees whatever else happens to be in `bazel-bin`, not only the declared
inputs of the action.

TypeScript 6 (JavaScript `tsc`) stays in the sandbox, most likely because the
rules_js Node.js fs patches keep resolved paths inside it; the native TypeScript 7
binary is not patched.

## Layout

Each subdirectory reproduces one issue with the same structure:

-   `lib`: a pnpm workspace package, linked into consumers via `npm_link_all_packages`
    (plus any workspace packages it depends on)
-   `app`: the consumer `ts_project`, whose compiler is selected by `//:typescript`

Every `app` fails with TypeScript 7, the default (for [outputs](outputs), a check
of its outputs fails), and succeeds with TypeScript 6:

```sh
bazel build //...
bazel build //... --//:typescript=6
```

## Mechanisms

### Relative imports resolve to copied `.ts` sources

`ts_project` copies its `.ts` sources to `bazel-bin` next to the `.d.ts` outputs.
Consumers only see the `.d.ts` files, but after escaping, a relative import such
as `./util` resolves to `util.ts`, which TypeScript prefers over `util.d.ts`.

-   [globals](globals): `util.ts` references the library's private `globals.d.ts`,
    a reference declaration emit drops. The escaped compilation pulls it in and it
    conflicts with the consumer's own globals (`TS2451`).
-   [badsyntax](badsyntax): `badsyntax.ts` is invalid and only a compiler that
    escapes the sandbox ever parses it (`TS1109`).
-   [strict](strict): an ordinary library compiled without `noImplicitAny`. The
    escaped compilation type-checks its `util.ts` under the consumer's `strict`
    options (`TS7006`). `skipLibCheck` does not help since these are `.ts` files,
    and every consumer re-checks the library's sources.

### An undeclared `package.json` changes the module format

-   [esm](esm): the library's `package.json` (`"type": "module"`) only reaches its
    own compilation via `ts_config(deps)`, so consumers treat its `index.d.ts` as
    CommonJS. It is still copied to `bazel-bin`, where the escaped compilation finds
    it and treats `index.d.ts` as ESM, which a CommonJS consumer under `node16`
    cannot `require` (`TS1479`).

### Parent `node_modules` lookups find undeclared packages

After escaping, resolving a bare specifier walks up the real directories and finds
`node_modules/<pkg>` links the action never declared.

-   [phantom](phantom): the library's emitted `index.d.ts` re-exports from
    `phantom-leaked`, a devDependency it only receives via `ts_config(deps)`.
    Consumers cannot resolve it and, with `skipLibCheck`, get `any`. The escaped
    compilation finds the library's own `node_modules/phantom-leaked` link and uses
    its real type (`TS2322`).

### The same file is loaded under two paths

-   [identity](identity): the consumer imports the library both by package name
    and by relative path, with every input declared. The package import resolves
    to the escaped execroot path while the relative import stays in the sandbox,
    so the program contains two copies of the same file and its class with a
    private member is incompatible with itself (`TS2322`).

### Outputs record escaped paths

-   [outputs](outputs): the build succeeds, but the `.tsbuildinfo` lists library
    files by their path out of the sandbox into the execroot. That path depends on
    the sandbox layout, so the same action produces different outputs sandboxed,
    locally or remotely. A genrule fails when a `.tsbuildinfo` mentions `execroot`.

## Workaround

`"preserveSymlinks": true` in the consumer's tsconfig keeps TypeScript 7 on the
sandbox paths and fixes every case above except [identity](identity), which then
fails with TypeScript 6 as well since the two import paths no longer converge.

## Not reproduced

These behave the same with TypeScript 6 and 7:

-   emitted `.d.ts` import paths for inferred library types (TypeScript 7 maps the
    escaped path back to the package specifier)
-   a library's devDependencies linked in its own package (rules_js also stages
    them for consumers)
-   relative imports and `tsconfig` globs from the consumer's own sources, which
    are never resolved through a symlink
-   the scenarios in [sandbox.bats](../test/sandbox.bats), which only escape
    without a sandbox

## Consequences

Any file an escaped compilation reads is an undeclared input: changing it does
not invalidate the consumer, so cached results can go stale.

## Platforms

The escape is not macOS specific: both `darwin-sandbox` and the default
`linux-sandbox` stage inputs as symlinks into the execroot. Windows has no sandbox.

This test enables `--experimental_use_hermetic_linux_sandbox` on Linux, which
hardlinks inputs and does not mount the execroot, so the TypeScript 7 targets are
expected to fail only on macOS.

## Materializing outputs

A compiler can only escape to files that exist in `bazel-bin`. With build without
the bytes and cache hits, the files it would find may never be downloaded, so
`.bazelrc` sets `--remote_download_outputs=all`.
