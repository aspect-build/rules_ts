<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for TypeScript rules

Nearly identical to the ts_project wrapper macro in npm @bazel/typescript.
Differences:
- this doesn't have the transpiler attribute yet
- doesn't have worker support
- uses the executables from @npm_typescript rather than what a user npm_install'ed
- didn't copy the whole doc string


<a id="#ts_config"></a>

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
| <a id="ts_config-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="ts_config-deps"></a>deps |  Additional tsconfig.json files referenced via extends   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="ts_config-src"></a>src |  The tsconfig.json file passed to the TypeScript compiler   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |


<a id="#validate_options"></a>

## validate_options

<pre>
validate_options(<a href="#validate_options-name">name</a>, <a href="#validate_options-allow_js">allow_js</a>, <a href="#validate_options-composite">composite</a>, <a href="#validate_options-declaration">declaration</a>, <a href="#validate_options-declaration_map">declaration_map</a>, <a href="#validate_options-emit_declaration_only">emit_declaration_only</a>,
                 <a href="#validate_options-extends">extends</a>, <a href="#validate_options-has_local_deps">has_local_deps</a>, <a href="#validate_options-incremental">incremental</a>, <a href="#validate_options-preserve_jsx">preserve_jsx</a>, <a href="#validate_options-resolve_json_module">resolve_json_module</a>, <a href="#validate_options-source_map">source_map</a>,
                 <a href="#validate_options-target">target</a>, <a href="#validate_options-ts_build_info_file">ts_build_info_file</a>, <a href="#validate_options-tsconfig">tsconfig</a>, <a href="#validate_options-validator">validator</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="validate_options-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="validate_options-allow_js"></a>allow_js |  https://www.typescriptlang.org/tsconfig#allowJs   | Boolean | optional | False |
| <a id="validate_options-composite"></a>composite |  https://www.typescriptlang.org/tsconfig#composite   | Boolean | optional | False |
| <a id="validate_options-declaration"></a>declaration |  https://www.typescriptlang.org/tsconfig#declaration   | Boolean | optional | False |
| <a id="validate_options-declaration_map"></a>declaration_map |  https://www.typescriptlang.org/tsconfig#declarationMap   | Boolean | optional | False |
| <a id="validate_options-emit_declaration_only"></a>emit_declaration_only |  https://www.typescriptlang.org/tsconfig#emitDeclarationOnly   | Boolean | optional | False |
| <a id="validate_options-extends"></a>extends |  https://www.typescriptlang.org/tsconfig#extends   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="validate_options-has_local_deps"></a>has_local_deps |  Whether any of the deps are in the local workspace   | Boolean | optional | False |
| <a id="validate_options-incremental"></a>incremental |  https://www.typescriptlang.org/tsconfig#incremental   | Boolean | optional | False |
| <a id="validate_options-preserve_jsx"></a>preserve_jsx |  https://www.typescriptlang.org/tsconfig#jsx   | Boolean | optional | False |
| <a id="validate_options-resolve_json_module"></a>resolve_json_module |  https://www.typescriptlang.org/tsconfig#resolveJsonModule   | Boolean | optional | False |
| <a id="validate_options-source_map"></a>source_map |  https://www.typescriptlang.org/tsconfig#sourceMap   | Boolean | optional | False |
| <a id="validate_options-target"></a>target |  -   | String | optional | "" |
| <a id="validate_options-ts_build_info_file"></a>ts_build_info_file |  -   | String | optional | "" |
| <a id="validate_options-tsconfig"></a>tsconfig |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="validate_options-validator"></a>validator |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |


<a id="#ts_project"></a>

## ts_project

<pre>
ts_project(<a href="#ts_project-name">name</a>, <a href="#ts_project-tsconfig">tsconfig</a>, <a href="#ts_project-srcs">srcs</a>, <a href="#ts_project-args">args</a>, <a href="#ts_project-data">data</a>, <a href="#ts_project-deps">deps</a>, <a href="#ts_project-extends">extends</a>, <a href="#ts_project-allow_js">allow_js</a>, <a href="#ts_project-declaration">declaration</a>, <a href="#ts_project-source_map">source_map</a>,
           <a href="#ts_project-declaration_map">declaration_map</a>, <a href="#ts_project-resolve_json_module">resolve_json_module</a>, <a href="#ts_project-preserve_jsx">preserve_jsx</a>, <a href="#ts_project-composite">composite</a>, <a href="#ts_project-incremental">incremental</a>,
           <a href="#ts_project-emit_declaration_only">emit_declaration_only</a>, <a href="#ts_project-ts_build_info_file">ts_build_info_file</a>, <a href="#ts_project-tsc">tsc</a>, <a href="#ts_project-validate">validate</a>, <a href="#ts_project-validator">validator</a>, <a href="#ts_project-declaration_dir">declaration_dir</a>,
           <a href="#ts_project-out_dir">out_dir</a>, <a href="#ts_project-root_dir">root_dir</a>, <a href="#ts_project-kwargs">kwargs</a>)
</pre>

Compiles one TypeScript project using `tsc --project`.

For the list of args, see the ts_project rule.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="ts_project-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="ts_project-tsconfig"></a>tsconfig |  <p align="center"> - </p>   |  <code>"tsconfig.json"</code> |
| <a id="ts_project-srcs"></a>srcs |  <p align="center"> - </p>   |  <code>None</code> |
| <a id="ts_project-args"></a>args |  <p align="center"> - </p>   |  <code>[]</code> |
| <a id="ts_project-data"></a>data |  <p align="center"> - </p>   |  <code>[]</code> |
| <a id="ts_project-deps"></a>deps |  <p align="center"> - </p>   |  <code>[]</code> |
| <a id="ts_project-extends"></a>extends |  <p align="center"> - </p>   |  <code>None</code> |
| <a id="ts_project-allow_js"></a>allow_js |  <p align="center"> - </p>   |  <code>False</code> |
| <a id="ts_project-declaration"></a>declaration |  <p align="center"> - </p>   |  <code>False</code> |
| <a id="ts_project-source_map"></a>source_map |  <p align="center"> - </p>   |  <code>False</code> |
| <a id="ts_project-declaration_map"></a>declaration_map |  <p align="center"> - </p>   |  <code>False</code> |
| <a id="ts_project-resolve_json_module"></a>resolve_json_module |  <p align="center"> - </p>   |  <code>None</code> |
| <a id="ts_project-preserve_jsx"></a>preserve_jsx |  <p align="center"> - </p>   |  <code>False</code> |
| <a id="ts_project-composite"></a>composite |  <p align="center"> - </p>   |  <code>False</code> |
| <a id="ts_project-incremental"></a>incremental |  <p align="center"> - </p>   |  <code>False</code> |
| <a id="ts_project-emit_declaration_only"></a>emit_declaration_only |  <p align="center"> - </p>   |  <code>False</code> |
| <a id="ts_project-ts_build_info_file"></a>ts_build_info_file |  <p align="center"> - </p>   |  <code>None</code> |
| <a id="ts_project-tsc"></a>tsc |  <p align="center"> - </p>   |  <code>"@npm_typescript//:tsc"</code> |
| <a id="ts_project-validate"></a>validate |  <p align="center"> - </p>   |  <code>True</code> |
| <a id="ts_project-validator"></a>validator |  <p align="center"> - </p>   |  <code>"@npm_typescript//:validator"</code> |
| <a id="ts_project-declaration_dir"></a>declaration_dir |  <p align="center"> - </p>   |  <code>None</code> |
| <a id="ts_project-out_dir"></a>out_dir |  <p align="center"> - </p>   |  <code>None</code> |
| <a id="ts_project-root_dir"></a>root_dir |  <p align="center"> - </p>   |  <code>None</code> |
| <a id="ts_project-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


