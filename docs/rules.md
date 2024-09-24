<!-- Generated with Stardoc: http://skydoc.bazel.build -->

# Public API for TypeScript rules

The most commonly used is the [ts_project](#ts_project) macro which accepts TypeScript sources as
inputs and produces JavaScript or declaration (.d.ts) outputs.

<a id="ts_config"></a>

## ts_config

<pre>
ts_config(<a href="#ts_config-name">name</a>, <a href="#ts_config-deps">deps</a>, <a href="#ts_config-src">src</a>)
</pre>

Allows a tsconfig.json file to extend another file.

Normally, you just give a single `tsconfig.json` file as the tsconfig attribute
of a `ts_library` or `ts_project` rule. However, if your `tsconfig.json` uses the `extends`
feature from TypeScript, then the Bazel implementation needs to know about that
extended configuration file as well, to pass them both to the TypeScript compiler.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ts_config-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="ts_config-deps"></a>deps |  Additional tsconfig.json files referenced via extends   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="ts_config-src"></a>src |  The tsconfig.json file passed to the TypeScript compiler   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="ts_project_rule"></a>

## ts_project_rule

<pre>
ts_project_rule(<a href="#ts_project_rule-name">name</a>, <a href="#ts_project_rule-deps">deps</a>, <a href="#ts_project_rule-srcs">srcs</a>, <a href="#ts_project_rule-data">data</a>, <a href="#ts_project_rule-allow_js">allow_js</a>, <a href="#ts_project_rule-args">args</a>, <a href="#ts_project_rule-assets">assets</a>, <a href="#ts_project_rule-buildinfo_out">buildinfo_out</a>, <a href="#ts_project_rule-composite">composite</a>,
                <a href="#ts_project_rule-declaration">declaration</a>, <a href="#ts_project_rule-declaration_dir">declaration_dir</a>, <a href="#ts_project_rule-declaration_map">declaration_map</a>, <a href="#ts_project_rule-emit_declaration_only">emit_declaration_only</a>, <a href="#ts_project_rule-extends">extends</a>,
                <a href="#ts_project_rule-incremental">incremental</a>, <a href="#ts_project_rule-is_typescript_5_or_greater">is_typescript_5_or_greater</a>, <a href="#ts_project_rule-isolated_typecheck">isolated_typecheck</a>, <a href="#ts_project_rule-js_outs">js_outs</a>, <a href="#ts_project_rule-map_outs">map_outs</a>,
                <a href="#ts_project_rule-no_emit">no_emit</a>, <a href="#ts_project_rule-out_dir">out_dir</a>, <a href="#ts_project_rule-preserve_jsx">preserve_jsx</a>, <a href="#ts_project_rule-resolve_json_module">resolve_json_module</a>, <a href="#ts_project_rule-resource_set">resource_set</a>, <a href="#ts_project_rule-root_dir">root_dir</a>,
                <a href="#ts_project_rule-source_map">source_map</a>, <a href="#ts_project_rule-supports_workers">supports_workers</a>, <a href="#ts_project_rule-transpile">transpile</a>, <a href="#ts_project_rule-ts_build_info_file">ts_build_info_file</a>, <a href="#ts_project_rule-tsc">tsc</a>, <a href="#ts_project_rule-tsc_worker">tsc_worker</a>,
                <a href="#ts_project_rule-tsconfig">tsconfig</a>, <a href="#ts_project_rule-typing_maps_outs">typing_maps_outs</a>, <a href="#ts_project_rule-typings_outs">typings_outs</a>, <a href="#ts_project_rule-validate">validate</a>, <a href="#ts_project_rule-validator">validator</a>)
</pre>

Implementation rule behind the ts_project macro.
Most users should use [ts_project](#ts_project) instead.

This skips conveniences like validation of the tsconfig attributes, default settings
for srcs and tsconfig, and pre-declaring output files.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ts_project_rule-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="ts_project_rule-deps"></a>deps |  List of targets that produce TypeScript typings (`.d.ts` files)<br><br>Follows the same runfiles semantics as `js_library` `deps` attribute. See https://docs.aspect.build/rulesets/aspect_rules_js/docs/js_library#deps for more info.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="ts_project_rule-srcs"></a>srcs |  TypeScript source files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="ts_project_rule-data"></a>data |  Runtime dependencies to include in binaries/tests that depend on this target.<br><br>Follows the same semantics as `js_library` `data` attribute. See https://docs.aspect.build/rulesets/aspect_rules_js/docs/js_library#data for more info.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="ts_project_rule-allow_js"></a>allow_js |  https://www.typescriptlang.org/tsconfig#allowJs   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-args"></a>args |  https://www.typescriptlang.org/docs/handbook/compiler-options.html   | List of strings | optional |  `[]`  |
| <a id="ts_project_rule-assets"></a>assets |  Files which are needed by a downstream build step such as a bundler.<br><br>See more details on the `assets` parameter of the `ts_project` macro.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="ts_project_rule-buildinfo_out"></a>buildinfo_out |  Location in bazel-out where tsc will write a `.tsbuildinfo` file   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="ts_project_rule-composite"></a>composite |  https://www.typescriptlang.org/tsconfig#composite   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-declaration"></a>declaration |  https://www.typescriptlang.org/tsconfig#declaration   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-declaration_dir"></a>declaration_dir |  https://www.typescriptlang.org/tsconfig#declarationDir   | String | optional |  `""`  |
| <a id="ts_project_rule-declaration_map"></a>declaration_map |  https://www.typescriptlang.org/tsconfig#declarationMap   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-emit_declaration_only"></a>emit_declaration_only |  https://www.typescriptlang.org/tsconfig#emitDeclarationOnly   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-extends"></a>extends |  https://www.typescriptlang.org/tsconfig#extends   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="ts_project_rule-incremental"></a>incremental |  https://www.typescriptlang.org/tsconfig#incremental   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-is_typescript_5_or_greater"></a>is_typescript_5_or_greater |  Whether TypeScript version is >= 5.0.0   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-isolated_typecheck"></a>isolated_typecheck |  Whether type-checking should be a separate action.<br><br>This allows the transpilation action to run without waiting for typings from dependencies.<br><br>Requires a minimum version of typescript 5.6 for the [noCheck](https://www.typescriptlang.org/tsconfig#noCheck) flag which is automatically set on the transpilation action when the typecheck action is isolated.<br><br>Requires [isolatedDeclarations](https://www.typescriptlang.org/tsconfig#isolatedDeclarations) to be set so that declarations can be emitted without dependencies. The use of `isolatedDeclarations` may require significant changes to your codebase and should be done as a pre-requisite to enabling `isolated_typecheck`.   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-js_outs"></a>js_outs |  Locations in bazel-out where tsc will write `.js` files   | List of labels | optional |  `[]`  |
| <a id="ts_project_rule-map_outs"></a>map_outs |  Locations in bazel-out where tsc will write `.js.map` files   | List of labels | optional |  `[]`  |
| <a id="ts_project_rule-no_emit"></a>no_emit |  https://www.typescriptlang.org/tsconfig#noEmit   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-out_dir"></a>out_dir |  https://www.typescriptlang.org/tsconfig#outDir   | String | optional |  `""`  |
| <a id="ts_project_rule-preserve_jsx"></a>preserve_jsx |  https://www.typescriptlang.org/tsconfig#jsx   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-resolve_json_module"></a>resolve_json_module |  https://www.typescriptlang.org/tsconfig#resolveJsonModule   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-resource_set"></a>resource_set |  A predefined function used as the resource_set for actions.<br><br>Used with --experimental_action_resource_set to reserve more RAM/CPU, preventing Bazel overscheduling resource-intensive actions.<br><br>By default, Bazel allocates 1 CPU and 250M of RAM. https://github.com/bazelbuild/bazel/blob/058f943037e21710837eda9ca2f85b5f8538c8c5/src/main/java/com/google/devtools/build/lib/actions/AbstractAction.java#L77   | String | optional |  `"default"`  |
| <a id="ts_project_rule-root_dir"></a>root_dir |  https://www.typescriptlang.org/tsconfig#rootDir   | String | optional |  `""`  |
| <a id="ts_project_rule-source_map"></a>source_map |  https://www.typescriptlang.org/tsconfig#sourceMap   | Boolean | optional |  `False`  |
| <a id="ts_project_rule-supports_workers"></a>supports_workers |  Whether to use a custom `tsc` compiler which understands Bazel's persistent worker protocol.<br><br>See the docs for `supports_workers` on the [`ts_project`](#ts_project-supports_workers) macro.   | Integer | optional |  `0`  |
| <a id="ts_project_rule-transpile"></a>transpile |  Whether tsc should be used to produce .js outputs<br><br>Values are: - -1: Error if --@aspect_rules_ts//ts:default_to_tsc_transpiler not set, otherwise transpile - 0: Do not transpile - 1: Transpile   | Integer | optional |  `-1`  |
| <a id="ts_project_rule-ts_build_info_file"></a>ts_build_info_file |  https://www.typescriptlang.org/tsconfig#tsBuildInfoFile   | String | optional |  `""`  |
| <a id="ts_project_rule-tsc"></a>tsc |  TypeScript compiler binary   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="ts_project_rule-tsc_worker"></a>tsc_worker |  TypeScript compiler worker binary   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="ts_project_rule-tsconfig"></a>tsconfig |  tsconfig.json file, see https://www.typescriptlang.org/tsconfig   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="ts_project_rule-typing_maps_outs"></a>typing_maps_outs |  Locations in bazel-out where tsc will write `.d.ts.map` files   | List of labels | optional |  `[]`  |
| <a id="ts_project_rule-typings_outs"></a>typings_outs |  Locations in bazel-out where tsc will write `.d.ts` files   | List of labels | optional |  `[]`  |
| <a id="ts_project_rule-validate"></a>validate |  whether to add a Validation Action to verify the other attributes match settings in the tsconfig.json file   | Boolean | optional |  `True`  |
| <a id="ts_project_rule-validator"></a>validator |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="TsConfigInfo"></a>

## TsConfigInfo

<pre>
TsConfigInfo(<a href="#TsConfigInfo-deps">deps</a>)
</pre>

Provides TypeScript configuration, in the form of a tsconfig.json file
along with any transitively referenced tsconfig.json files chained by the
"extends" feature

**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="TsConfigInfo-deps"></a>deps |  all tsconfig.json files needed to configure TypeScript    |


<a id="ts_project"></a>

## ts_project

<pre>
ts_project(<a href="#ts_project-name">name</a>, <a href="#ts_project-tsconfig">tsconfig</a>, <a href="#ts_project-srcs">srcs</a>, <a href="#ts_project-args">args</a>, <a href="#ts_project-data">data</a>, <a href="#ts_project-deps">deps</a>, <a href="#ts_project-assets">assets</a>, <a href="#ts_project-extends">extends</a>, <a href="#ts_project-allow_js">allow_js</a>, <a href="#ts_project-isolated_typecheck">isolated_typecheck</a>,
           <a href="#ts_project-declaration">declaration</a>, <a href="#ts_project-source_map">source_map</a>, <a href="#ts_project-declaration_map">declaration_map</a>, <a href="#ts_project-resolve_json_module">resolve_json_module</a>, <a href="#ts_project-preserve_jsx">preserve_jsx</a>, <a href="#ts_project-composite">composite</a>,
           <a href="#ts_project-incremental">incremental</a>, <a href="#ts_project-no_emit">no_emit</a>, <a href="#ts_project-emit_declaration_only">emit_declaration_only</a>, <a href="#ts_project-transpiler">transpiler</a>, <a href="#ts_project-ts_build_info_file">ts_build_info_file</a>, <a href="#ts_project-tsc">tsc</a>,
           <a href="#ts_project-tsc_worker">tsc_worker</a>, <a href="#ts_project-validate">validate</a>, <a href="#ts_project-validator">validator</a>, <a href="#ts_project-declaration_dir">declaration_dir</a>, <a href="#ts_project-out_dir">out_dir</a>, <a href="#ts_project-root_dir">root_dir</a>, <a href="#ts_project-supports_workers">supports_workers</a>,
           <a href="#ts_project-kwargs">kwargs</a>)
</pre>

Compiles one TypeScript project using `tsc --project`.

This is a drop-in replacement for the `tsc` rule automatically generated for the "typescript"
package, typically loaded from `@npm//typescript:package_json.bzl`.
Unlike bare `tsc`, this rule understands the Bazel interop mechanism (Providers)
so that this rule works with others that produce or consume TypeScript typings (`.d.ts` files).

One of the benefits of using ts_project is that it understands the [Bazel Worker Protocol]
which makes the overhead of starting the compiler be a one-time cost.
Worker mode is on by default to speed up build and typechecking process.

Some TypeScript options affect which files are emitted, and Bazel needs to predict these ahead-of-time.
As a result, several options from the tsconfig file must be mirrored as attributes to ts_project.
A validation action is run to help ensure that these are correctly mirrored.
See https://www.typescriptlang.org/tsconfig for a listing of the TypeScript options.

If you have problems getting your `ts_project` to work correctly, read the dedicated
[troubleshooting guide](/docs/troubleshooting.md).

[Bazel Worker Protocol]: https://bazel.build/remote/persistent


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="ts_project-name"></a>name |  a name for this target   |  none |
| <a id="ts_project-tsconfig"></a>tsconfig |  Label of the tsconfig.json file to use for the compilation. To support "chaining" of more than one extended config, this label could be a target that provides `TsConfigInfo` such as `ts_config`.<br><br>By default, if a "tsconfig.json" file is in the same folder with the ts_project rule, it is used.<br><br>Instead of a label, you can pass a dictionary matching the JSON schema.<br><br>See [docs/tsconfig.md](/docs/tsconfig.md) for detailed information.   |  `None` |
| <a id="ts_project-srcs"></a>srcs |  List of labels of TypeScript source files to be provided to the compiler.<br><br>If absent, the default is set as follows:<br><br>- Include all TypeScript files in the package, recursively. - If `allow_js` is set, include all JavaScript files in the package as well. - If `resolve_json_module` is set, include all JSON files in the package,   but exclude `package.json`, `package-lock.json`, and `tsconfig*.json`.   |  `None` |
| <a id="ts_project-args"></a>args |  List of strings of additional command-line arguments to pass to tsc. See https://www.typescriptlang.org/docs/handbook/compiler-options.html#compiler-options Typically useful arguments for debugging are `--listFiles` and `--listEmittedFiles`.   |  `[]` |
| <a id="ts_project-data"></a>data |  Files needed at runtime by binaries or tests that transitively depend on this target. See https://bazel.build/reference/be/common-definitions#typical-attributes   |  `[]` |
| <a id="ts_project-deps"></a>deps |  List of targets that produce TypeScript typings (`.d.ts` files)<br><br>If this list contains linked npm packages, npm package store targets or other targets that provide `JsInfo`, `NpmPackageStoreInfo` providers are gathered from `JsInfo`. This is done directly from the `npm_package_store_deps` field of these. For linked npm package targets, the underlying `npm_package_store` target(s) that back the links is used. Gathered `NpmPackageStoreInfo` providers are propagated to the direct dependencies of downstream linked `npm_package` targets.<br><br>NB: Linked npm package targets that are "dev" dependencies do not forward their underlying `npm_package_store` target(s) through `npm_package_store_deps` and will therefore not be propagated to the direct dependencies of downstream linked `npm_package` targets. npm packages that come in from `npm_translate_lock` are considered "dev" dependencies if they are have `dev: true` set in the pnpm lock file. This should be all packages that are only listed as "devDependencies" in all `package.json` files within the pnpm workspace. This behavior is intentional to mimic how `devDependencies` work in published npm packages.   |  `[]` |
| <a id="ts_project-assets"></a>assets |  Files which are needed by a downstream build step such as a bundler.<br><br>These files are **not** included as inputs to any actions spawned by `ts_project`. They are not transpiled, and are not visible to the type-checker. Instead, these files appear among the *outputs* of this target.<br><br>A typical use is when your TypeScript code has an import that TS itself doesn't understand such as<br><br>`import './my.scss'`<br><br>and the type-checker allows this because you have an "ambient" global type declaration like<br><br>`declare module '*.scss' { ... }`<br><br>A bundler like webpack will expect to be able to resolve the `./my.scss` import to a file and doesn't care about the typing declaration. A bundler runs as a build step, so it does not see files included in the `data` attribute.<br><br>Note that `data` is used for files that are resolved by some binary, including a test target. Behind the scenes, `data` populates Bazel's Runfiles object in `DefaultInfo`, while this attribute populates the `transitive_sources` of the `JsInfo`.   |  `[]` |
| <a id="ts_project-extends"></a>extends |  Label of the tsconfig file referenced in the `extends` section of tsconfig To support "chaining" of more than one extended config, this label could be a target that provdes `TsConfigInfo` such as `ts_config`.   |  `None` |
| <a id="ts_project-allow_js"></a>allow_js |  Whether TypeScript will read .js and .jsx files. When used with `declaration`, TypeScript will generate `.d.ts` files from `.js` files.   |  `False` |
| <a id="ts_project-isolated_typecheck"></a>isolated_typecheck |  Whether to type-check asynchronously as a separate bazel action. Requires https://devblogs.microsoft.com/typescript/announcing-typescript-5-6/#the---nocheck-option6 Requires https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-5.html#isolated-declarations   |  `False` |
| <a id="ts_project-declaration"></a>declaration |  Whether the `declaration` bit is set in the tsconfig. Instructs Bazel to expect a `.d.ts` output for each `.ts` source.   |  `False` |
| <a id="ts_project-source_map"></a>source_map |  Whether the `sourceMap` bit is set in the tsconfig. Instructs Bazel to expect a `.js.map` output for each `.ts` source.   |  `False` |
| <a id="ts_project-declaration_map"></a>declaration_map |  Whether the `declarationMap` bit is set in the tsconfig. Instructs Bazel to expect a `.d.ts.map` output for each `.ts` source.   |  `False` |
| <a id="ts_project-resolve_json_module"></a>resolve_json_module |  Boolean; specifies whether TypeScript will read .json files. If set to True or False and tsconfig is a dict, resolveJsonModule is set in the generated config file. If set to None and tsconfig is a dict, resolveJsonModule is unset in the generated config and typescript default or extended tsconfig value will be load bearing.   |  `None` |
| <a id="ts_project-preserve_jsx"></a>preserve_jsx |  Whether the `jsx` value is set to "preserve" in the tsconfig. Instructs Bazel to expect a `.jsx` or `.jsx.map` output for each `.tsx` source.   |  `False` |
| <a id="ts_project-composite"></a>composite |  Whether the `composite` bit is set in the tsconfig. Instructs Bazel to expect a `.tsbuildinfo` output and a `.d.ts` output for each `.ts` source.   |  `False` |
| <a id="ts_project-incremental"></a>incremental |  Whether the `incremental` bit is set in the tsconfig. Instructs Bazel to expect a `.tsbuildinfo` output.   |  `False` |
| <a id="ts_project-no_emit"></a>no_emit |  Whether the `noEmit` bit is set in the tsconfig. Instructs Bazel *not* to expect any outputs.   |  `False` |
| <a id="ts_project-emit_declaration_only"></a>emit_declaration_only |  Whether the `emitDeclarationOnly` bit is set in the tsconfig. Instructs Bazel *not* to expect `.js` or `.js.map` outputs for `.ts` sources.   |  `False` |
| <a id="ts_project-transpiler"></a>transpiler |  A custom transpiler tool to run that produces the JavaScript outputs instead of `tsc`.<br><br>Under `--@aspect_rules_ts//ts:default_to_tsc_transpiler`, the default is to use `tsc` to produce `.js` outputs in the same action that does the type-checking to produce `.d.ts` outputs. This is the simplest configuration, however `tsc` is slower than alternatives. It also means developers must wait for the type-checking in the developer loop.<br><br>Without `--@aspect_rules_ts//ts:default_to_tsc_transpiler`, an explicit value must be set. This may be the string `"tsc"` to explicitly choose `tsc`, just like the default above.<br><br>It may also be any rule or macro with this signature: `(name, srcs, **kwargs)`<br><br>See [docs/transpiler.md](/docs/transpiler.md) for more details.   |  `None` |
| <a id="ts_project-ts_build_info_file"></a>ts_build_info_file |  The user-specified value of `tsBuildInfoFile` from the tsconfig. Helps Bazel to predict the path where the .tsbuildinfo output is written.   |  `None` |
| <a id="ts_project-tsc"></a>tsc |  Label of the TypeScript compiler binary to run. This allows you to use a custom API-compatible compiler in place of the regular `tsc` such as a custom `js_binary` or Angular's `ngc`. compatible with it such as Angular's `ngc`.<br><br>See examples of use in [examples/custom_compiler](https://github.com/aspect-build/rules_ts/blob/main/examples/custom_compiler/BUILD.bazel)   |  `"@npm_typescript//:tsc"` |
| <a id="ts_project-tsc_worker"></a>tsc_worker |  Label of a custom TypeScript compiler binary which understands Bazel's persistent worker protocol.   |  `"@npm_typescript//:tsc_worker"` |
| <a id="ts_project-validate"></a>validate |  Whether to check that the dependencies are valid and the tsconfig JSON settings match the attributes on this target. Set this to `False` to skip running our validator, in case you have a legitimate reason for these to differ, e.g. you have a setting enabled just for the editor but you want different behavior when Bazel runs `tsc`.   |  `True` |
| <a id="ts_project-validator"></a>validator |  Label of the tsconfig validator to run when `validate = True`.   |  `"@npm_typescript//:validator"` |
| <a id="ts_project-declaration_dir"></a>declaration_dir |  String specifying a subdirectory under the bazel-out folder where generated declaration outputs are written. Equivalent to the TypeScript --declarationDir option. By default declarations are written to the out_dir.   |  `None` |
| <a id="ts_project-out_dir"></a>out_dir |  String specifying a subdirectory under the bazel-out folder where outputs are written. Equivalent to the TypeScript --outDir option.<br><br>Note that Bazel always requires outputs be written under a subdirectory matching the input package, so if your rule appears in `path/to/my/package/BUILD.bazel` and out_dir = "foo" then the .js files will appear in `bazel-out/[arch]/bin/path/to/my/package/foo/*.js`.<br><br>By default the out_dir is the package's folder under bazel-out.   |  `None` |
| <a id="ts_project-root_dir"></a>root_dir |  String specifying a subdirectory under the input package which should be consider the root directory of all the input files. Equivalent to the TypeScript --rootDir option. By default it is '.', meaning the source directory where the BUILD file lives.   |  `None` |
| <a id="ts_project-supports_workers"></a>supports_workers |  Whether the "Persistent Worker" protocol is enabled. This uses a custom `tsc` compiler to make rebuilds faster. Note that this causes some known correctness bugs, see https://docs.aspect.build/rules/aspect_rules_ts/docs/troubleshooting. We do not intend to fix these bugs.<br><br>Worker mode can be enabled for all `ts_project`s in a build with the global `--@aspect_rules_ts//ts:supports_workers` flag. To enable worker mode for all builds in the workspace, add `build --@aspect_rules_ts//ts:supports_workers` to the .bazelrc.<br><br>This is a "tri-state" attribute, accepting values `[-1, 0, 1]`. The behavior is:<br><br>- `-1`: use the value of the global `--@aspect_rules_ts//ts:supports_workers` flag. - `0`: Override the global flag, disabling workers for this target. - `1`: Override the global flag, enabling workers for this target.   |  `-1` |
| <a id="ts_project-kwargs"></a>kwargs |  passed through to underlying [`ts_project_rule`](#ts_project_rule), eg. `visibility`, `tags`   |  none |


