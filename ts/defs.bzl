"""# Public API for TypeScript rules

The most commonly used is the [ts_project](#ts_project) macro which accepts TypeScript sources as
inputs and produces JavaScript or declaration (.d.ts) outputs.
"""

load("@aspect_bazel_lib//lib:utils.bzl", "to_label")
load("@bazel_skylib//lib:partial.bzl", "partial")
load("//ts/private:build_test.bzl", "build_test")
load("//ts/private:ts_config.bzl", "write_tsconfig", _TsConfigInfo = "TsConfigInfo", _ts_config = "ts_config")
load("//ts/private:ts_lib.bzl", _lib = "lib")
load("//ts/private:ts_project.bzl", _ts_project = "ts_project")

ts_config = _ts_config
TsConfigInfo = _TsConfigInfo
ts_project_rule = _ts_project

def _is_file_missing(label):
    """Check if a file is missing by passing its relative path through a glob().

    Args
        label: the file's label
    """
    file_abs = "%s/%s" % (label.package, label.name)
    file_rel = file_abs[len(native.package_name()) + 1:]
    file_glob = native.glob([file_rel], allow_empty = True)
    return len(file_glob) == 0

_tsc = "@npm_typescript//:tsc"
_tsc_worker = "@npm_typescript//:tsc_worker"

def ts_project(
        name,
        tsconfig = None,
        srcs = None,
        args = [],
        data = [],
        deps = [],
        assets = [],
        extends = None,
        allow_js = False,
        isolated_typecheck = False,
        declaration = False,
        source_map = False,
        declaration_map = False,
        resolve_json_module = None,
        preserve_jsx = False,
        composite = False,
        incremental = False,
        no_emit = False,
        emit_declaration_only = False,
        transpiler = None,
        declaration_transpiler = None,
        ts_build_info_file = None,
        generate_trace = None,
        tsc = _tsc,
        tsc_worker = _tsc_worker,
        validate = True,
        validator = "@npm_typescript//:validator",
        declaration_dir = None,
        out_dir = None,
        root_dir = None,
        supports_workers = -1,
        **kwargs):
    """Compiles one TypeScript project using `tsc --project`.

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

    Args:
        name: a name for this target

        srcs: List of labels of TypeScript source files to be provided to the compiler.

            If absent, the default is set as follows:

            - Include all TypeScript files in the package, recursively.
            - If `allow_js` is set, include all JavaScript files in the package as well.
            - If `resolve_json_module` is set, include all JSON files in the package,
              but exclude `package.json`, `package-lock.json`, and `tsconfig*.json`.

        assets: Files which are needed by a downstream build step such as a bundler.

            These files are **not** included as inputs to any actions spawned by `ts_project`.
            They are not transpiled, and are not visible to the type-checker.
            Instead, these files appear among the *outputs* of this target.

            A typical use is when your TypeScript code has an import that TS itself doesn't understand
            such as

            `import './my.scss'`

            and the type-checker allows this because you have an "ambient" global type declaration like

            `declare module '*.scss' { ... }`

            A bundler like webpack will expect to be able to resolve the `./my.scss` import to a file
            and doesn't care about the typing declaration. A bundler runs as a build step,
            so it does not see files included in the `data` attribute.

            Note that `data` is used for files that are resolved by some binary, including a test
            target. Behind the scenes, `data` populates Bazel's Runfiles object in `DefaultInfo`,
            while this attribute populates the `transitive_sources` of the `JsInfo`.

        data: Files needed at runtime by binaries or tests that transitively depend on this target.
            See https://bazel.build/reference/be/common-definitions#typical-attributes

        deps: List of targets that produce TypeScript typings (`.d.ts` files)

            If this list contains linked npm packages, npm package store targets or other targets that provide
            `JsInfo`, `NpmPackageStoreInfo` providers are gathered from `JsInfo`. This is done directly from
            the `npm_package_store_deps` field of these. For linked npm package targets, the underlying
            `npm_package_store` target(s) that back the links is used. Gathered `NpmPackageStoreInfo`
            providers are propagated to the direct dependencies of downstream linked `npm_package` targets.

            NB: Linked npm package targets that are "dev" dependencies do not forward their underlying
            `npm_package_store` target(s) through `npm_package_store_deps` and will therefore not be
            propagated to the direct dependencies of downstream linked `npm_package` targets. npm packages
            that come in from `npm_translate_lock` are considered "dev" dependencies if they are have
            `dev: true` set in the pnpm lock file. This should be all packages that are only listed as
            "devDependencies" in all `package.json` files within the pnpm workspace. This behavior is
            intentional to mimic how `devDependencies` work in published npm packages.

        tsconfig: Label of the tsconfig.json file to use for the compilation.
            To support "chaining" of more than one extended config, this label could be a target that
            provides `TsConfigInfo` such as `ts_config`.

            By default, if a "tsconfig.json" file is in the same folder with the ts_project rule, it is used.

            Instead of a label, you can pass a dictionary matching the JSON schema.

            See [docs/tsconfig.md](/docs/tsconfig.md) for detailed information.

        extends: Label of the tsconfig file referenced in the `extends` section of tsconfig
            To support "chaining" of more than one extended config, this label could be a target that
            provdes `TsConfigInfo` such as `ts_config`.

        args: List of strings of additional command-line arguments to pass to tsc.
            See https://www.typescriptlang.org/docs/handbook/compiler-options.html#compiler-options
            Typically useful arguments for debugging are `--listFiles` and `--listEmittedFiles`.

        isolated_typecheck: Whether to type-check asynchronously as a separate bazel action.
            Requires https://devblogs.microsoft.com/typescript/announcing-typescript-5-6/#the---nocheck-option6
            Requires https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-5.html#isolated-declarations

        transpiler: A custom transpiler tool to run that produces the JavaScript outputs instead of `tsc`.

            Under `--@aspect_rules_ts//ts:default_to_tsc_transpiler`, the default is to use `tsc` to produce
            `.js` outputs in the same action that does the type-checking to produce `.d.ts` outputs.
            This is the simplest configuration, however `tsc` is slower than alternatives.
            It also means developers must wait for the type-checking in the developer loop.

            Without `--@aspect_rules_ts//ts:default_to_tsc_transpiler`, an explicit value must be set.
            This may be the string `"tsc"` to explicitly choose `tsc`, just like the default above.

            It may also be any rule or macro with this signature: `(name, srcs, **kwargs)`

            If JavaScript outputs are configured to not be emitted the custom transpiler will not be used, such as
            when `no_emit = True` or `emit_declaration_only = True`.

            See [docs/transpiler.md](/docs/transpiler.md) for more details.

        declaration_transpiler: A custom transpiler tool to run that produces the TypeScript declaration outputs instead of `tsc`.

            It may be any rule or macro with this signature: `(name, srcs, **kwargs)`

            If TypeScript declaration outputs are configured to not be emitted the custom declaration transpiler will
            not be used, such as when `no_emit = True` or `declaration = False`.

            See [docs/transpiler.md](/docs/transpiler.md) for more details.

        validate: Whether to check that the dependencies are valid and the tsconfig JSON settings match the attributes on this target.
            Set this to `False` to skip running our validator, in case you have a legitimate reason for these to differ,
            e.g. you have a setting enabled just for the editor but you want different behavior when Bazel runs `tsc`.

        root_dir: String specifying a subdirectory under the input package which should be consider the
            root directory of all the input files.
            Equivalent to the TypeScript --rootDir option.
            By default it is '.', meaning the source directory where the BUILD file lives.

        out_dir: String specifying a subdirectory under the bazel-out folder where outputs are written.
            Equivalent to the TypeScript --outDir option.

            Note that Bazel always requires outputs be written under a subdirectory matching the input package,
            so if your rule appears in `path/to/my/package/BUILD.bazel` and out_dir = "foo" then the .js files
            will appear in `bazel-out/[arch]/bin/path/to/my/package/foo/*.js`.

            By default the out_dir is the package's folder under bazel-out.

        tsc: Label of the TypeScript compiler binary to run.
            This allows you to use a custom API-compatible compiler in place of the regular `tsc` such as a custom `js_binary` or Angular's `ngc`.
            compatible with it such as Angular's `ngc`.

            See examples of use in [examples/custom_compiler](https://github.com/aspect-build/rules_ts/blob/main/examples/custom_compiler/BUILD.bazel)

        tsc_worker: Label of a custom TypeScript compiler binary which understands Bazel's persistent worker protocol.
        validator: Label of the tsconfig validator to run when `validate = True`.
        allow_js: Whether TypeScript will read .js and .jsx files.
            When used with `declaration`, TypeScript will generate `.d.ts` files from `.js` files.
        resolve_json_module: Boolean; specifies whether TypeScript will read .json files.
            If set to True or False and tsconfig is a dict, resolveJsonModule is set in the generated config file.
            If set to None and tsconfig is a dict, resolveJsonModule is unset in the generated config and typescript
            default or extended tsconfig value will be load bearing.

        declaration_dir: String specifying a subdirectory under the bazel-out folder where generated declaration
            outputs are written. Equivalent to the TypeScript --declarationDir option.
            By default declarations are written to the out_dir.

        declaration: Whether the `declaration` bit is set in the tsconfig.
            Instructs Bazel to expect a `.d.ts` output for each `.ts` source.
        source_map: Whether the `sourceMap` bit is set in the tsconfig.
            Instructs Bazel to expect a `.js.map` output for each `.ts` source.
        declaration_map: Whether the `declarationMap` bit is set in the tsconfig.
            Instructs Bazel to expect a `.d.ts.map` output for each `.ts` source.
        preserve_jsx: Whether the `jsx` value is set to "preserve" in the tsconfig.
            Instructs Bazel to expect a `.jsx` or `.jsx.map` output for each `.tsx` source.
        composite: Whether the `composite` bit is set in the tsconfig.
            Instructs Bazel to expect a `.tsbuildinfo` output and a `.d.ts` output for each `.ts` source.
        incremental: Whether the `incremental` bit is set in the tsconfig.
            Instructs Bazel to expect a `.tsbuildinfo` output.
        no_emit: Whether the `noEmit` bit is set in the tsconfig.
            Instructs Bazel *not* to expect any outputs.
        emit_declaration_only: Whether the `emitDeclarationOnly` bit is set in the tsconfig.
            Instructs Bazel *not* to expect `.js` or `.js.map` outputs for `.ts` sources.
        ts_build_info_file: The user-specified value of `tsBuildInfoFile` from the tsconfig.
            Helps Bazel to predict the path where the .tsbuildinfo output is written.
        generate_trace: Whether to generate a trace file for TypeScript compiler performance analysis.
            When enabled, creates a trace directory containing performance tracing information that can be
            loaded in chrome://tracing. Use the `--@aspect_rules_ts//ts:generate_tsc_trace` flag to enable this by default.

        supports_workers: Whether the "Persistent Worker" protocol is enabled.
            This uses a custom `tsc` compiler to make rebuilds faster.
            Note that this causes some known correctness bugs, see
            https://docs.aspect.build/rules/aspect_rules_ts/docs/troubleshooting.
            We do not intend to fix these bugs.

            Worker mode can be enabled for all `ts_project`s in a build with the global
            `--@aspect_rules_ts//ts:supports_workers` flag.
            To enable worker mode for all builds in the workspace, add
            `build --@aspect_rules_ts//ts:supports_workers` to the .bazelrc.

            This is a "tri-state" attribute, accepting values `[-1, 0, 1]`. The behavior is:

            - `-1`: use the value of the global `--@aspect_rules_ts//ts:supports_workers` flag.
            - `0`: Override the global flag, disabling workers for this target.
            - `1`: Override the global flag, enabling workers for this target.

        **kwargs: passed through to underlying [`ts_project_rule`](#ts_project_rule), eg. `visibility`, `tags`
    """

    tsc_deps = deps

    common_kwargs = {
        "tags": kwargs.get("tags", []),
        "visibility": kwargs.get("visibility", None),
        "testonly": kwargs.get("testonly", None),
    }

    if tsconfig == None:
        if _is_file_missing(to_label(":tsconfig.json")):
            fail("No tsconfig.json file found in {}/. You must set the tsconfig attribute on {}.".format(
                native.package_name(),
                to_label(name),
            ))
        else:
            tsconfig = "tsconfig.json"

    if type(tsconfig) == type(dict()):
        # Copy attributes <-> tsconfig properties
        tsconfig = dict(tsconfig)
        tsconfig["compilerOptions"] = dict(tsconfig.get("compilerOptions", {}))

        # TODO: fail if compilerOptions includes a conflict with an attribute?
        compiler_options = tsconfig["compilerOptions"]
        source_map = compiler_options.setdefault("sourceMap", source_map)
        declaration = compiler_options.setdefault("declaration", declaration)
        declaration_map = compiler_options.setdefault("declarationMap", declaration_map)
        no_emit = compiler_options.setdefault("noEmit", no_emit)
        emit_declaration_only = compiler_options.setdefault("emitDeclarationOnly", emit_declaration_only)
        allow_js = compiler_options.setdefault("allowJs", allow_js)
        resolve_json_module = compiler_options.setdefault("resolveJsonModule", resolve_json_module)

        # These options are always passed on the tsc command line so don't include them
        # in the tsconfig. At best they're redundant, but at worst we'll have a conflict
        out_dir = compiler_options.pop("outDir", out_dir)
        declaration_dir = compiler_options.pop("declarationDir", declaration_dir)
        root_dir = compiler_options.pop("rootDir", root_dir)

        # When generating a tsconfig.json and we set rootDir we need to add the exclude field,
        # because of these tickets (validation for not generated tsconfig is also present elsewhere):
        # https://github.com/microsoft/TypeScript/issues/59036 and
        # 'https://github.com/aspect-build/rules_ts/issues/644
        if root_dir != None and "exclude" not in tsconfig:
            tsconfig["exclude"] = []

        if srcs == None:
            # Default sources based on macro attributes after applying tsconfig properties
            srcs = _default_srcs(
                allow_js = allow_js,
                resolve_json_module = resolve_json_module,
            )

        # FIXME: need to remove keys that have a None value?
        write_tsconfig(
            name = "_gen_tsconfig_%s" % name,
            config = tsconfig,
            files = srcs,
            extends = extends,
            out = "tsconfig_%s.json" % name,
            allow_js = allow_js,
            resolve_json_module = resolve_json_module,
            **common_kwargs
        )

        # From here, tsconfig becomes a file, the same as if the
        # user supplied a tsconfig.json InputArtifact
        tsconfig = "tsconfig_%s.json" % name
    elif srcs == None:
        # Default sources based on macro attributes
        srcs = _default_srcs(
            allow_js = allow_js,
            resolve_json_module = resolve_json_module,
        )

    # Normalize common directory path shortcuts such as None vs "." vs "./"
    out_dir = _clean_dir_arg(out_dir)
    root_dir = _clean_dir_arg(root_dir)
    declaration_dir = _clean_dir_arg(declaration_dir)

    # Inferred paths
    typings_out_dir = declaration_dir if declaration_dir else out_dir
    tsbuildinfo_path = ts_build_info_file if ts_build_info_file else name + ".tsbuildinfo"

    # Flags for what is emitted and which tool is emitting them
    emit_js = not no_emit and not emit_declaration_only
    emit_dts = not no_emit and (declaration or emit_declaration_only)
    emit_transpiler_js = emit_js and transpiler and transpiler != "tsc"
    emit_transpiler_dts = emit_dts and declaration_transpiler
    emit_tsc_js = emit_js and not emit_transpiler_js
    emit_tsc_dts = emit_dts and not emit_transpiler_dts

    # Target names for tsc, dts+js transpilers
    declarations_target_name = None
    transpile_target_name = None

    # typing predeclared outputs
    tsc_typings_outs = []
    tsc_typing_maps_outs = []
    if emit_tsc_dts:
        tsc_typings_outs = _lib.calculate_typings_outs(srcs, typings_out_dir, root_dir, declaration, composite, allow_js)
        tsc_typing_maps_outs = _lib.calculate_typing_maps_outs(srcs, typings_out_dir, root_dir, declaration_map, allow_js)

    # js predeclared outputs
    tsc_js_outs = []
    tsc_map_outs = []
    if emit_tsc_js:
        tsc_js_outs = _lib.calculate_js_outs(srcs, out_dir, root_dir, allow_js, resolve_json_module, preserve_jsx, emit_declaration_only)
        tsc_map_outs = _lib.calculate_map_outs(srcs, out_dir, root_dir, source_map, allow_js, preserve_jsx, emit_declaration_only)

    # Custom typing transpiler
    if emit_transpiler_dts:
        declarations_target_name = "%s_declarations" % name
        _invoke_custom_transpiler("declaration_transpiler", declaration_transpiler, declarations_target_name, srcs, common_kwargs)

    # Custom js transpiler
    if emit_transpiler_js:
        transpile_target_name = "%s_transpile" % name
        _invoke_custom_transpiler("transpiler", transpiler, transpile_target_name, srcs, common_kwargs)

    # Users should build this target to get typing files
    types_target_name = "%s_types" % name
    if not no_emit:
        if declarations_target_name:
            # A standalone target outputs the types
            native.alias(
                name = types_target_name,
                actual = declarations_target_name,
                visibility = common_kwargs.get("visibility"),
                tags = common_kwargs.get("tags", []),
            )
        else:
            # tsc outputs the types and must be extracted via output_group
            native.filegroup(
                name = types_target_name,
                srcs = [name],
                output_group = "types",
                **common_kwargs
            )

    # If the primary target does not output dts files then type-checking has a separate target.
    if not emit_tsc_js or not emit_tsc_dts or isolated_typecheck:
        typecheck_target_name = "%s_typecheck" % name
        transitive_typecheck_target_name = "%s_transitive_typecheck" % name
        test_target_name = "%s_typecheck_test" % name
        transitive_typecheck_test_target_name = "%s_transitive_typecheck_test" % name

        # Users should build this target to get a failed build when typechecking fails
        native.filegroup(
            name = typecheck_target_name,
            srcs = [name],
            output_group = "typecheck",
            **common_kwargs
        )

        # Users should build this target to get a failed build when typechecking fails
        native.filegroup(
            name = transitive_typecheck_target_name,
            srcs = [name],
            output_group = "transitive_typecheck",
            tags = ["manual"] + common_kwargs.get("tags", []),
            visibility = common_kwargs.get("visibility"),
            testonly = common_kwargs.get("testonly"),
        )

        # Ensures the typecheck target gets built under `bazel test --build_tests_only`
        build_test(
            name = test_target_name,
            targets = [typecheck_target_name],
            tags = common_kwargs.get("tags"),
            size = "small",
            visibility = common_kwargs.get("visibility"),
        )

        build_test(
            name = transitive_typecheck_test_target_name,
            targets = [transitive_typecheck_target_name],
            tags = ["manual"] + common_kwargs.get("tags", []),
            size = "small",
            visibility = common_kwargs.get("visibility"),
        )

    # Disable workers if a custom tsc was provided but not a custom tsc_worker.
    if tsc != _tsc and tsc_worker == _tsc_worker:
        supports_workers = 0

    # Disable typescript version detection if tsc is not the default:
    # - it would be wrong anyways
    # - it is only used to warn if worker support is configured incorrectly.
    if tsc != _tsc or tsc_worker != _tsc_worker:
        is_typescript_5_or_greater = None
    else:
        is_typescript_5_or_greater = select({
            "@npm_typescript//:is_typescript_5_or_greater": True,
            "//conditions:default": False,
        })

    ts_project_rule(
        name = name,
        srcs = srcs,
        args = args,
        assets = assets,
        data = data,
        deps = tsc_deps,
        tsconfig = tsconfig,
        allow_js = allow_js,
        resolve_json_module = resolve_json_module,
        extends = extends,
        incremental = incremental,
        preserve_jsx = preserve_jsx,
        composite = composite,
        isolated_typecheck = isolated_typecheck,
        declaration = declaration,
        declaration_dir = declaration_dir,
        source_map = source_map,
        declaration_map = declaration_map,
        ts_build_info_file = ts_build_info_file,
        generate_trace = generate_trace,
        out_dir = out_dir,
        root_dir = root_dir,
        js_outs = tsc_js_outs,
        map_outs = tsc_map_outs,
        typings_outs = tsc_typings_outs,
        typing_maps_outs = tsc_typing_maps_outs,
        buildinfo_out = tsbuildinfo_path if composite or incremental else None,
        no_emit = no_emit,
        emit_declaration_only = emit_declaration_only,
        tsc = tsc,
        tsc_worker = tsc_worker,
        transpile = -1 if not transpiler else int(transpiler == "tsc"),
        declaration_transpile = declaration_transpiler != None,
        pretranspiled_js = transpile_target_name,
        pretranspiled_dts = declarations_target_name,
        supports_workers = supports_workers,
        is_typescript_5_or_greater = is_typescript_5_or_greater,
        validate = validate,
        validator = validator,
        **kwargs
    )

def _default_srcs(allow_js, resolve_json_module):
    """Returns a list of srcs for ts_project when srcs is not provided."""
    include = ["**/*.ts", "**/*.tsx"]
    exclude = []

    if allow_js == True:
        include.extend(["**/*.js", "**/*.jsx"])

    if resolve_json_module == True:
        include.append("**/*.json")
        exclude.extend(["**/package.json", "**/package-lock.json", "**/tsconfig*.json"])

    return native.glob(include, exclude, allow_empty = True)

def _invoke_custom_transpiler(type_str, transpiler, transpile_target_name, srcs, common_kwargs):
    if type(transpiler) == "function" or type(transpiler) == "rule":
        transpiler(
            name = transpile_target_name,
            srcs = srcs,
            **common_kwargs
        )
    elif partial.is_instance(transpiler):
        partial.call(
            transpiler,
            name = transpile_target_name,
            srcs = srcs,
            **common_kwargs
        )
    else:
        fail("%s attribute should be a rule/macro or a skylib partial. Got %s" % (type_str, type(transpiler)))

def _clean_dir_arg(p):
    if not p or p == "." or p == "./":
        return None
    return p.removeprefix("./")
