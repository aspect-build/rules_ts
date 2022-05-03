<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies


<a id="#http_archive_version"></a>

## http_archive_version

<pre>
http_archive_version(<a href="#http_archive_version-name">name</a>, <a href="#http_archive_version-build_file">build_file</a>, <a href="#http_archive_version-integrity">integrity</a>, <a href="#http_archive_version-repo_mapping">repo_mapping</a>, <a href="#http_archive_version-urls">urls</a>, <a href="#http_archive_version-version">version</a>, <a href="#http_archive_version-version_from">version_from</a>)
</pre>

Re-implementation of http_archive that can read the version from package.json

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="http_archive_version-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="http_archive_version-build_file"></a>build_file |  The BUILD file to symlink into the created repository.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="http_archive_version-integrity"></a>integrity |  Needed only if the ts version isn't mirrored in <code>versions.bzl</code>.   | String | optional | "" |
| <a id="http_archive_version-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="http_archive_version-urls"></a>urls |  URLs to fetch from. Each must have one <code>{}</code>-style placeholder.   | List of strings | optional | [] |
| <a id="http_archive_version-version"></a>version |  Explicit version for <code>urls</code> placeholder. If provided, the package.json is not read.   | String | optional | "" |
| <a id="http_archive_version-version_from"></a>version_from |  Location of package.json which may have a version for the package.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a id="#rules_ts_dependencies"></a>

## rules_ts_dependencies

<pre>
rules_ts_dependencies(<a href="#rules_ts_dependencies-ts_version_from">ts_version_from</a>, <a href="#rules_ts_dependencies-ts_version">ts_version</a>, <a href="#rules_ts_dependencies-ts_integrity">ts_integrity</a>)
</pre>

Dependencies needed by users of rules_ts.

To skip fetching the typescript package, define repository called 'npm_typescript' before calling this.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rules_ts_dependencies-ts_version_from"></a>ts_version_from |  label of a json file (typically <code>package.json</code>) which declares an exact typescript version in a dependencies or devDependencies property. Exactly one of <code>ts_version</code> or <code>ts_version_from</code> must be set.   |  <code>None</code> |
| <a id="rules_ts_dependencies-ts_version"></a>ts_version |  version of the TypeScript compiler. Exactly one of <code>ts_version</code> or <code>ts_version_from</code> must be set.   |  <code>None</code> |
| <a id="rules_ts_dependencies-ts_integrity"></a>ts_integrity |  integrity hash for the npm package. By default, uses values mirrored into rules_ts. For example, to get the integrity of version 4.6.3 you could run <code>curl --silent https://registry.npmjs.org/typescript/4.6.3 | jq -r '.dist.integrity'</code>   |  <code>None</code> |


