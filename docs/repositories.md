<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies


<a id="rules_ts_dependencies"></a>

## rules_ts_dependencies

<pre>
rules_ts_dependencies(<a href="#rules_ts_dependencies-ts_version_from">ts_version_from</a>, <a href="#rules_ts_dependencies-ts_version">ts_version</a>, <a href="#rules_ts_dependencies-ts_integrity">ts_integrity</a>, <a href="#rules_ts_dependencies-check_for_updates">check_for_updates</a>)
</pre>

Dependencies needed by users of rules_ts.

To skip fetching the typescript package, call `rules_ts_bazel_dependencies` instead.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rules_ts_dependencies-ts_version_from"></a>ts_version_from |  label of a json file which declares a typescript version.<br><br>This may be a <code>package.json</code> file, with "typescript" in the dependencies or devDependencies property, and the version exactly specified.<br><br>With rules_js v1.32.0 or greater, it may also be a <code>resolved.json</code> file produced by <code>npm_translate_lock</code>, such as <code>@npm//path/to/linked:typescript/resolved.json</code><br><br>Exactly one of <code>ts_version</code> or <code>ts_version_from</code> must be set.   |  <code>None</code> |
| <a id="rules_ts_dependencies-ts_version"></a>ts_version |  version of the TypeScript compiler. Exactly one of <code>ts_version</code> or <code>ts_version_from</code> must be set.   |  <code>None</code> |
| <a id="rules_ts_dependencies-ts_integrity"></a>ts_integrity |  integrity hash for the npm package. By default, uses values mirrored into rules_ts. For example, to get the integrity of version 4.6.3 you could run <code>curl --silent https://registry.npmjs.org/typescript/4.6.3 | jq -r '.dist.integrity'</code>   |  <code>None</code> |
| <a id="rules_ts_dependencies-check_for_updates"></a>check_for_updates |  Whether to check for newer releases of rules_ts and notify the user with a log message when an update is available.<br><br>Note, to better understand our users, we also include basic information about the build in the request to the update server. This never includes confidential or personally-identifying information (PII). The values sent are:<br><br>- Currently used version. Helps us understand which older release(s) users are stuck on. - bzlmod (true/false). Helps us roll out this feature which is mandatory by Bazel 9. - Some CI-related environment variables to understand usage:     - BUILDKITE_ORGANIZATION_SLUG     - CIRCLE_PROJECT_USERNAME (this is *not* the username of the logged in user)     - GITHUB_REPOSITORY_OWNER     - BUILDKITE_BUILD_NUMBER     - CIRCLE_BUILD_NUM     - GITHUB_RUN_NUMBER   |  <code>True</code> |


