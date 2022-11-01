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
| <a id="ts_config-deps"></a>deps |  Additional tsconfig.json files referenced via extends   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | [] |
| <a id="ts_config-src"></a>src |  The tsconfig.json file passed to the TypeScript compiler   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="ts_project_rule"></a>

## ts_project_rule

<pre>
ts_project_rule(<a href="#ts_project_rule-name">name</a>, <a href="#ts_project_rule-allow_js">allow_js</a>, <a href="#ts_project_rule-args">args</a>, <a href="#ts_project_rule-buildinfo_out">buildinfo_out</a>, <a href="#ts_project_rule-composite">composite</a>, <a href="#ts_project_rule-data">data</a>, <a href="#ts_project_rule-declaration">declaration</a>, <a href="#ts_project_rule-declaration_dir">declaration_dir</a>,
                <a href="#ts_project_rule-declaration_map">declaration_map</a>, <a href="#ts_project_rule-deps">deps</a>, <a href="#ts_project_rule-emit_declaration_only">emit_declaration_only</a>, <a href="#ts_project_rule-extends">extends</a>, <a href="#ts_project_rule-incremental">incremental</a>, <a href="#ts_project_rule-js_outs">js_outs</a>, <a href="#ts_project_rule-map_outs">map_outs</a>,
                <a href="#ts_project_rule-out_dir">out_dir</a>, <a href="#ts_project_rule-preserve_jsx">preserve_jsx</a>, <a href="#ts_project_rule-resolve_json_module">resolve_json_module</a>, <a href="#ts_project_rule-root_dir">root_dir</a>, <a href="#ts_project_rule-source_map">source_map</a>, <a href="#ts_project_rule-srcs">srcs</a>,
                <a href="#ts_project_rule-supports_workers">supports_workers</a>, <a href="#ts_project_rule-transpile">transpile</a>, <a href="#ts_project_rule-tsc">tsc</a>, <a href="#ts_project_rule-tsc_worker">tsc_worker</a>, <a href="#ts_project_rule-tsconfig">tsconfig</a>, <a href="#ts_project_rule-typing_maps_outs">typing_maps_outs</a>,
                <a href="#ts_project_rule-typings_outs">typings_outs</a>)
</pre>

Implementation rule behind the ts_project macro.
    Most users should use [ts_project](#ts_project) instead.

    This skips conveniences like validation of the tsconfig attributes, default settings
    for srcs and tsconfig, and pre-declaring output files.
    

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ts_project_rule-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="ts_project_rule-allow_js"></a>allow_js |  https://www.typescriptlang.org/tsconfig#allowJs   | Boolean | optional | False |
| <a id="ts_project_rule-args"></a>args |  https://www.typescriptlang.org/docs/handbook/compiler-options.html   | List of strings | optional | [] |
| <a id="ts_project_rule-buildinfo_out"></a>buildinfo_out |  Location in bazel-out where tsc will write a <code>.tsbuildinfo</code> file   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  |
| <a id="ts_project_rule-composite"></a>composite |  https://www.typescriptlang.org/tsconfig#composite   | Boolean | optional | False |
| <a id="ts_project_rule-data"></a>data |  Runtime dependencies to include in binaries/tests that depend on this target.<br><br>    The transitive npm dependencies, transitive sources, default outputs and runfiles of targets in the <code>data</code> attribute     are added to the runfiles of this taregt. Thery should appear in the '*.runfiles' area of any executable which has     a runtime dependency on this target.<br><br>    If this list contains linked npm packages, npm package store targets or other targets that provide <code>JsInfo</code>,     <code>NpmPackageStoreInfo</code> providers are gathered from <code>JsInfo</code>. This is done directly from the     <code>npm_package_store_deps</code> field of these. For linked npm package targets, the underlying npm_package_store     target(s) that back the links is used.<br><br>    Gathered <code>NpmPackageStoreInfo</code> providers are used downstream as direct dependencies when linking a downstream     <code>npm_package</code> target with <code>npm_link_package</code>.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | [] |
| <a id="ts_project_rule-declaration"></a>declaration |  https://www.typescriptlang.org/tsconfig#declaration   | Boolean | optional | False |
| <a id="ts_project_rule-declaration_dir"></a>declaration_dir |  https://www.typescriptlang.org/tsconfig#declarationDir   | String | optional | "" |
| <a id="ts_project_rule-declaration_map"></a>declaration_map |  https://www.typescriptlang.org/tsconfig#declarationMap   | Boolean | optional | False |
| <a id="ts_project_rule-deps"></a>deps |  Other targets which produce TypeScript typings   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional | [] |
| <a id="ts_project_rule-emit_declaration_only"></a>emit_declaration_only |  https://www.typescriptlang.org/tsconfig#emitDeclarationOnly   | Boolean | optional | False |
| <a id="ts_project_rule-extends"></a>extends |  https://www.typescriptlang.org/tsconfig#extends   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | None |
| <a id="ts_project_rule-incremental"></a>incremental |  https://www.typescriptlang.org/tsconfig#incremental   | Boolean | optional | False |
| <a id="ts_project_rule-js_outs"></a>js_outs |  Locations in bazel-out where tsc will write <code>.js</code> files   | List of labels | optional |  |
| <a id="ts_project_rule-map_outs"></a>map_outs |  Locations in bazel-out where tsc will write <code>.js.map</code> files   | List of labels | optional |  |
| <a id="ts_project_rule-out_dir"></a>out_dir |  https://www.typescriptlang.org/tsconfig#outDir   | String | optional | "" |
| <a id="ts_project_rule-preserve_jsx"></a>preserve_jsx |  https://www.typescriptlang.org/tsconfig#jsx   | Boolean | optional | False |
| <a id="ts_project_rule-resolve_json_module"></a>resolve_json_module |  https://www.typescriptlang.org/tsconfig#resolveJsonModule   | Boolean | optional | False |
| <a id="ts_project_rule-root_dir"></a>root_dir |  https://www.typescriptlang.org/tsconfig#rootDir   | String | optional | "" |
| <a id="ts_project_rule-source_map"></a>source_map |  https://www.typescriptlang.org/tsconfig#sourceMap   | Boolean | optional | False |
| <a id="ts_project_rule-srcs"></a>srcs |  TypeScript source files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="ts_project_rule-supports_workers"></a>supports_workers |  Whether the tsc compiler understands Bazel's persistent worker protocol   | Boolean | optional | False |
| <a id="ts_project_rule-transpile"></a>transpile |  whether tsc should be used to produce .js outputs   | Boolean | optional | True |
| <a id="ts_project_rule-tsc"></a>tsc |  TypeScript compiler binary   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="ts_project_rule-tsc_worker"></a>tsc_worker |  TypeScript compiler worker binary   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="ts_project_rule-tsconfig"></a>tsconfig |  tsconfig.json file, see https://www.typescriptlang.org/tsconfig   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="ts_project_rule-typing_maps_outs"></a>typing_maps_outs |  Locations in bazel-out where tsc will write <code>.d.ts.map</code> files   | List of labels | optional |  |
| <a id="ts_project_rule-typings_outs"></a>typings_outs |  Locations in bazel-out where tsc will write <code>.d.ts</code> files   | List of labels | optional |  |


<a id="validate_options"></a>

## validate_options

<pre>
validate_options(<a href="#validate_options-name">name</a>, <a href="#validate_options-allow_js">allow_js</a>, <a href="#validate_options-composite">composite</a>, <a href="#validate_options-declaration">declaration</a>, <a href="#validate_options-declaration_map">declaration_map</a>, <a href="#validate_options-deps">deps</a>,
                 <a href="#validate_options-emit_declaration_only">emit_declaration_only</a>, <a href="#validate_options-extends">extends</a>, <a href="#validate_options-incremental">incremental</a>, <a href="#validate_options-preserve_jsx">preserve_jsx</a>, <a href="#validate_options-resolve_json_module">resolve_json_module</a>,
                 <a href="#validate_options-source_map">source_map</a>, <a href="#validate_options-target">target</a>, <a href="#validate_options-ts_build_info_file">ts_build_info_file</a>, <a href="#validate_options-tsconfig">tsconfig</a>, <a href="#validate_options-validator">validator</a>)
</pre>

Validates that some tsconfig.json properties match attributes on ts_project.
    See the documentation of [`ts_project`](#ts_project) for more information.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="validate_options-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="validate_options-allow_js"></a>allow_js |  https://www.typescriptlang.org/tsconfig#allowJs   | Boolean | optional | False |
| <a id="validate_options-composite"></a>composite |  https://www.typescriptlang.org/tsconfig#composite   | Boolean | optional | False |
| <a id="validate_options-declaration"></a>declaration |  https://www.typescriptlang.org/tsconfig#declaration   | Boolean | optional | False |
| <a id="validate_options-declaration_map"></a>declaration_map |  https://www.typescriptlang.org/tsconfig#declarationMap   | Boolean | optional | False |
| <a id="validate_options-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="validate_options-emit_declaration_only"></a>emit_declaration_only |  https://www.typescriptlang.org/tsconfig#emitDeclarationOnly   | Boolean | optional | False |
| <a id="validate_options-extends"></a>extends |  https://www.typescriptlang.org/tsconfig#extends   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | None |
| <a id="validate_options-incremental"></a>incremental |  https://www.typescriptlang.org/tsconfig#incremental   | Boolean | optional | False |
| <a id="validate_options-preserve_jsx"></a>preserve_jsx |  https://www.typescriptlang.org/tsconfig#jsx   | Boolean | optional | False |
| <a id="validate_options-resolve_json_module"></a>resolve_json_module |  https://www.typescriptlang.org/tsconfig#resolveJsonModule   | Boolean | optional | False |
| <a id="validate_options-source_map"></a>source_map |  https://www.typescriptlang.org/tsconfig#sourceMap   | Boolean | optional | False |
| <a id="validate_options-target"></a>target |  -   | String | optional | "" |
| <a id="validate_options-ts_build_info_file"></a>ts_build_info_file |  -   | String | optional | "" |
| <a id="validate_options-tsconfig"></a>tsconfig |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="validate_options-validator"></a>validator |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


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
ts_project(<a href="#ts_project-name">name</a>, <a href="#ts_project-tsconfig">tsconfig</a>, <a href="#ts_project-srcs">srcs</a>, <a href="#ts_project-args">args</a>, <a href="#ts_project-data">data</a>, <a href="#ts_project-deps">deps</a>, <a href="#ts_project-extends">extends</a>, <a href="#ts_project-allow_js">allow_js</a>, <a href="#ts_project-declaration">declaration</a>, <a href="#ts_project-source_map">source_map</a>,
           <a href="#ts_project-declaration_map">declaration_map</a>, <a href="#ts_project-resolve_json_module">resolve_json_module</a>, <a href="#ts_project-preserve_jsx">preserve_jsx</a>, <a href="#ts_project-composite">composite</a>, <a href="#ts_project-incremental">incremental</a>,
           <a href="#ts_project-emit_declaration_only">emit_declaration_only</a>, <a href="#ts_project-transpiler">transpiler</a>, <a href="#ts_project-ts_build_info_file">ts_build_info_file</a>, <a href="#ts_project-tsc">tsc</a>, <a href="#ts_project-tsc_worker">tsc_worker</a>, <a href="#ts_project-validate">validate</a>,
           <a href="#ts_project-validator">validator</a>, <a href="#ts_project-declaration_dir">declaration_dir</a>, <a href="#ts_project-out_dir">out_dir</a>, <a href="#ts_project-root_dir">root_dir</a>, <a href="#ts_project-supports_workers">supports_workers</a>, <a href="#ts_project-kwargs">kwargs</a>)
</pre>

Compiles one TypeScript project using `tsc --project`.

This is a drop-in replacement for the `tsc` rule automatically generated for the "typescript"
package, typically loaded from `@npm//typescript:package_json.bzl`.
Unlike bare `tsc`, this rule understands the Bazel interop mechanism (Providers)
so that this rule works with others that produce or consume TypeScript typings (`.d.ts` files).

One of the benefits of using ts_project is that it understands Bazel Worker Protocol which makes
JIT overhead one time cost. Worker mode is on by default to speed up build and typechecking process.

Some TypeScript options affect which files are emitted, and Bazel needs to predict these ahead-of-time.
As a result, several options from the tsconfig file must be mirrored as attributes to ts_project.
A validator action is run to help ensure that these are correctly mirrored.
See https://www.typescriptlang.org/tsconfig for a listing of the TypeScript options.

Any code that works with `tsc` should work with `ts_project` with a few caveats:

- `ts_project` always produces some output files, or else Bazel would never run it.
  Therefore you shouldn't use it with TypeScript's `noEmit` option.
  If you only want to test that the code typechecks, use `tsc` directly;
  see [examples/typecheck_only](/examples/typecheck_only)
- Your tsconfig settings for `outDir` and `declarationDir` are ignored.
  Bazel requires that the `outDir` (and `declarationDir`) be set beneath
  `bazel-out/[target architecture]/bin/path/to/package`.
- Bazel expects that each output is produced by a single rule.
  Thus if you have two `ts_project` rules with overlapping sources (the same `.ts` file
  appears in more than one) then you get an error about conflicting `.js` output
  files if you try to build both together.
  Worse, if you build them separately then the output directory will contain whichever
  one you happened to build most recently. This is highly discouraged.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="ts_project-name"></a>name |  a name for this target   |  none |
| <a id="ts_project-tsconfig"></a>tsconfig |  Label of the tsconfig.json file to use for the compilation. To support "chaining" of more than one extended config, this label could be a target that provides <code>TsConfigInfo</code> such as <code>ts_config</code>.<br><br>By default, if a "tsconfig.json" file is in the same folder with the ts_project rule, it is used.<br><br>Instead of a label, you can pass a dictionary matching the JSON schema.<br><br>See [docs/tsconfig.md](/docs/tsconfig.md) for detailed information.   |  <code>None</code> |
| <a id="ts_project-srcs"></a>srcs |  List of labels of TypeScript source files to be provided to the compiler.<br><br>If absent, the default is set as follows:<br><br>- Include all TypeScript files in the package, recursively. - If <code>allow_js</code> is set, include all JavaScript files in the package as well. - If <code>resolve_json_module</code> is set, include all JSON files in the package,   but exclude <code>package.json</code>, <code>package-lock.json</code>, and <code>tsconfig*.json</code>.   |  <code>None</code> |
| <a id="ts_project-args"></a>args |  List of strings of additional command-line arguments to pass to tsc. See https://www.typescriptlang.org/docs/handbook/compiler-options.html#compiler-options Typically useful arguments for debugging are <code>--listFiles</code> and <code>--listEmittedFiles</code>.   |  <code>[]</code> |
| <a id="ts_project-data"></a>data |  Files needed at runtime by binaries or tests that transitively depend on this target. See https://bazel.build/reference/be/common-definitions#typical-attributes   |  <code>[]</code> |
| <a id="ts_project-deps"></a>deps |  List of labels of other rules that produce TypeScript typings (.d.ts files)   |  <code>[]</code> |
| <a id="ts_project-extends"></a>extends |  Label of the tsconfig file referenced in the <code>extends</code> section of tsconfig To support "chaining" of more than one extended config, this label could be a target that provdes <code>TsConfigInfo</code> such as <code>ts_config</code>.   |  <code>None</code> |
| <a id="ts_project-allow_js"></a>allow_js |  Whether TypeScript will read .js and .jsx files. When used with <code>declaration</code>, TypeScript will generate <code>.d.ts</code> files from <code>.js</code> files.   |  <code>False</code> |
| <a id="ts_project-declaration"></a>declaration |  Whether the <code>declaration</code> bit is set in the tsconfig. Instructs Bazel to expect a <code>.d.ts</code> output for each <code>.ts</code> source.   |  <code>False</code> |
| <a id="ts_project-source_map"></a>source_map |  Whether the <code>sourceMap</code> bit is set in the tsconfig. Instructs Bazel to expect a <code>.js.map</code> output for each <code>.ts</code> source.   |  <code>False</code> |
| <a id="ts_project-declaration_map"></a>declaration_map |  Whether the <code>declarationMap</code> bit is set in the tsconfig. Instructs Bazel to expect a <code>.d.ts.map</code> output for each <code>.ts</code> source.   |  <code>False</code> |
| <a id="ts_project-resolve_json_module"></a>resolve_json_module |  Boolean; specifies whether TypeScript will read .json files. If set to True or False and tsconfig is a dict, resolveJsonModule is set in the generated config file. If set to None and tsconfig is a dict, resolveJsonModule is unset in the generated config and typescript default or extended tsconfig value will be load bearing.   |  <code>None</code> |
| <a id="ts_project-preserve_jsx"></a>preserve_jsx |  Whether the <code>jsx</code> value is set to "preserve" in the tsconfig. Instructs Bazel to expect a <code>.jsx</code> or <code>.jsx.map</code> output for each <code>.tsx</code> source.   |  <code>False</code> |
| <a id="ts_project-composite"></a>composite |  Whether the <code>composite</code> bit is set in the tsconfig. Instructs Bazel to expect a <code>.tsbuildinfo</code> output and a <code>.d.ts</code> output for each <code>.ts</code> source.   |  <code>False</code> |
| <a id="ts_project-incremental"></a>incremental |  Whether the <code>incremental</code> bit is set in the tsconfig. Instructs Bazel to expect a <code>.tsbuildinfo</code> output.   |  <code>False</code> |
| <a id="ts_project-emit_declaration_only"></a>emit_declaration_only |  Whether the <code>emitDeclarationOnly</code> bit is set in the tsconfig. Instructs Bazel *not* to expect <code>.js</code> or <code>.js.map</code> outputs for <code>.ts</code> sources.   |  <code>False</code> |
| <a id="ts_project-transpiler"></a>transpiler |  A custom transpiler tool to run that produces the JavaScript outputs instead of <code>tsc</code>.<br><br>By default, <code>ts_project</code> expects <code>.js</code> outputs to be written in the same action that does the type-checking to produce <code>.d.ts</code> outputs. This is the simplest configuration, however <code>tsc</code> is slower than alternatives. It also means developers must wait for the type-checking in the developer loop.<br><br>See [docs/transpiler.md](/docs/transpiler.md) for more details.   |  <code>None</code> |
| <a id="ts_project-ts_build_info_file"></a>ts_build_info_file |  The user-specified value of <code>tsBuildInfoFile</code> from the tsconfig. Helps Bazel to predict the path where the .tsbuildinfo output is written.   |  <code>None</code> |
| <a id="ts_project-tsc"></a>tsc |  Label of the TypeScript compiler binary to run. This allows you to use a custom compiler.   |  <code>"@npm_typescript//:tsc"</code> |
| <a id="ts_project-tsc_worker"></a>tsc_worker |  Label of a custom TypeScript compiler binary which understands Bazel's persistent worker protocol.   |  <code>"@npm_typescript//:tsc_worker"</code> |
| <a id="ts_project-validate"></a>validate |  Whether to check that the dependencies are valid and the tsconfig JSON settings match the attributes on this target. Set this to <code>False</code> to skip running our validator, in case you have a legitimate reason for these to differ, e.g. you have a setting enabled just for the editor but you want different behavior when Bazel runs <code>tsc</code>.   |  <code>True</code> |
| <a id="ts_project-validator"></a>validator |  Label of the tsconfig validator to run when <code>validate = True</code>.   |  <code>"@npm_typescript//:validator"</code> |
| <a id="ts_project-declaration_dir"></a>declaration_dir |  String specifying a subdirectory under the bazel-out folder where generated declaration outputs are written. Equivalent to the TypeScript --declarationDir option. By default declarations are written to the out_dir.   |  <code>None</code> |
| <a id="ts_project-out_dir"></a>out_dir |  String specifying a subdirectory under the bazel-out folder where outputs are written. Equivalent to the TypeScript --outDir option.<br><br>Note that Bazel always requires outputs be written under a subdirectory matching the input package, so if your rule appears in <code>path/to/my/package/BUILD.bazel</code> and out_dir = "foo" then the .js files will appear in <code>bazel-out/[arch]/bin/path/to/my/package/foo/*.js</code>.<br><br>By default the out_dir is the package's folder under bazel-out.   |  <code>None</code> |
| <a id="ts_project-root_dir"></a>root_dir |  String specifying a subdirectory under the input package which should be consider the root directory of all the input files. Equivalent to the TypeScript --rootDir option. By default it is '.', meaning the source directory where the BUILD file lives.   |  <code>None</code> |
| <a id="ts_project-supports_workers"></a>supports_workers |  Whether the worker protocol is enabled. To disable worker mode for a particular target set <code>supports_workers</code> to <code>False</code>. Worker mode can be controlled as well via <code>--strategy</code> and <code>mnemonic</code> and  using .bazelrc.<br><br>Put this in your .bazelrc to disable it globally: <code>build --strategy=TsProject=sandboxed</code><br><br>See https://docs.bazel.build/versions/main/user-manual.html#flag--strategy for more details.   |  <code>True</code> |
| <a id="ts_project-kwargs"></a>kwargs |  passed through to underlying [<code>ts_project_rule</code>](#ts_project_rule), eg. <code>visibility</code>, <code>tags</code>   |  none |


