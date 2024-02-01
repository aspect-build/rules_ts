<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies


<a id="rules_ts_dependencies"></a>

## rules_ts_dependencies

<pre>
rules_ts_dependencies(<a href="#rules_ts_dependencies-ts_version_from">ts_version_from</a>, <a href="#rules_ts_dependencies-ts_version">ts_version</a>, <a href="#rules_ts_dependencies-ts_integrity">ts_integrity</a>)
</pre>

Dependencies needed by users of rules_ts.

To skip fetching the typescript package, call `rules_ts_bazel_dependencies` instead.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rules_ts_dependencies-ts_version_from"></a>ts_version_from |  label of a json file which declares a typescript version.<br><br>This may be a <code>package.json</code> file, with "typescript" in the dependencies or devDependencies property, and the version exactly specified.<br><br>With rules_js v1.32.0 or greater, it may also be a <code>resolved.json</code> file produced by <code>npm_translate_lock</code>, such as <code>@npm//path/to/linked:typescript/resolved.json</code><br><br>Exactly one of <code>ts_version</code> or <code>ts_version_from</code> must be set.   |  <code>None</code> |
| <a id="rules_ts_dependencies-ts_version"></a>ts_version |  version of the TypeScript compiler. Exactly one of <code>ts_version</code> or <code>ts_version_from</code> must be set.   |  <code>None</code> |
| <a id="rules_ts_dependencies-ts_integrity"></a>ts_integrity |  integrity hash for the npm package. By default, uses values mirrored into rules_ts. For example, to get the integrity of version 4.6.3 you could run <code>curl --silent https://registry.npmjs.org/typescript/4.6.3 | jq -r '.dist.integrity'</code>   |  <code>None</code> |


