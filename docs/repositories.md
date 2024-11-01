<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies

<a id="rules_ts_dependencies"></a>

## rules_ts_dependencies

<pre>
load("@aspect_rules_ts//ts:repositories.bzl", "rules_ts_dependencies")

rules_ts_dependencies(<a href="#rules_ts_dependencies-name">name</a>, <a href="#rules_ts_dependencies-ts_version_from">ts_version_from</a>, <a href="#rules_ts_dependencies-ts_version">ts_version</a>, <a href="#rules_ts_dependencies-ts_integrity">ts_integrity</a>)
</pre>

Dependencies needed by users of rules_ts.

To skip fetching the typescript package, call `rules_ts_bazel_dependencies` instead.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rules_ts_dependencies-name"></a>name |  name of the resulting external repository containing the TypeScript compiler.   |  `"npm_typescript"` |
| <a id="rules_ts_dependencies-ts_version_from"></a>ts_version_from |  label of a json file which declares a typescript version.<br><br>This may be a `package.json` file, with "typescript" in the dependencies or devDependencies property, and the version exactly specified.<br><br>With rules_js v1.32.0 or greater, it may also be a `resolved.json` file produced by `npm_translate_lock`, such as `@npm//path/to/linked:typescript/resolved.json`<br><br>Exactly one of `ts_version` or `ts_version_from` must be set.   |  `None` |
| <a id="rules_ts_dependencies-ts_version"></a>ts_version |  version of the TypeScript compiler. Exactly one of `ts_version` or `ts_version_from` must be set.   |  `None` |
| <a id="rules_ts_dependencies-ts_integrity"></a>ts_integrity |  integrity hash for the npm package. By default, uses values mirrored into rules_ts. For example, to get the integrity of version 4.6.3 you could run `curl --silent https://registry.npmjs.org/typescript/4.6.3 \| jq -r '.dist.integrity'`   |  `None` |


