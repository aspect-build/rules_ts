"""Public API for TypeScript rules

Nearly identical to the ts_project wrapper macro in npm @bazel/typescript.
Differences:
- uses the executables from @npm_typescript rather than what a user npm_install'ed
- didn't copy the whole doc string
"""

load("@aspect_bazel_lib//lib:utils.bzl", "is_external_label", "to_label")
load("@aspect_rules_js//js:defs.bzl", "js_library")
load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//ts/private:ts_config.bzl", "write_tsconfig", _ts_config = "ts_config")
load("//ts/private:ts_project.bzl", _ts_project_lib = "ts_project")
load("//ts/private:ts_validate_options.bzl", validate_lib = "lib")
load("//ts/private:ts_lib.bzl", _lib = "lib")

ts_config = _ts_config

validate_options = rule(
    doc = """Validates that some tsconfig.json properties match attributes on ts_project.
    See the documentation of [`ts_project`](#ts_project) for more information.""",
    implementation = validate_lib.implementation,
    attrs = validate_lib.attrs,
)

ts_project_rule = rule(
    doc = """Implementation rule behind the ts_project macro.
    Most users should use [ts_project](#ts_project) instead.
    """,
    implementation = _ts_project_lib.implementation,
    attrs = dict(_ts_project_lib.attrs),
)

def _is_file_missing(label):
    """Check if a file is missing by passing its relative path through a glob().

    Args
        label: the file's label
    """
    file_abs = "%s/%s" % (label.package, label.name)
    file_rel = file_abs[len(native.package_name()) + 1:]
    file_glob = native.glob([file_rel])
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
        extends = None,
        allow_js = False,
        declaration = False,
        source_map = False,
        declaration_map = False,
        resolve_json_module = None,
        preserve_jsx = False,
        composite = False,
        incremental = False,
        emit_declaration_only = False,
        transpiler = None,
        ts_build_info_file = None,
        tsc = _tsc,
        tsc_worker = _tsc_worker,
        validate = True,
        validator = "@npm_typescript//:validator",
        declaration_dir = None,
        out_dir = None,
        root_dir = None,
        supports_workers = True,
        **kwargs):
    """Compiles one TypeScript project using `tsc --project`.

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

    - ts_project` always produces some output files, or else Bazel would never run it.
      Therefore you shouldn't use it with TypeScript's `noEmit` option.
      If you only want to test that the code typechecks, instead use
      ```
      load("@npm//typescript:package_json.bzl", "bin")
      bin.tsc_test( ... )
      ```
    - Your tsconfig settings for `outDir` and `declarationDir` are ignored.
      Bazel requires that the `outDir` (and `declarationDir`) be set beneath
      `bazel-out/[target architecture]/bin/path/to/package`.
    - Bazel expects that each output is produced by a single rule.
      Thus if you have two `ts_project` rules with overlapping sources (the same `.ts` file
      appears in more than one) then you get an error about conflicting `.js` output
      files if you try to build both together.
      Worse, if you build them separately then the output directory will contain whichever
      one you happened to build most recently. This is highly discouraged.

    Args:
        name: a name for this target

        srcs: List of labels of TypeScript source files to be provided to the compiler.

            If absent, the default is set as follows:

            - Include `**/*.ts[x]` (all TypeScript files in the package).
            - If `allow_js` is set, include `**/*.js[x]` (all JavaScript files in the package).
            - If `resolve_json_module` is set, include `**/*.json` (all JSON files in the package),
              but exclude `**/package.json`, `**/package-lock.json`, and `**/tsconfig*.json`.

        data: Files needed at runtime by binaries or tests that transitively depend on this target.
            See https://bazel.build/reference/be/common-definitions#typical-attributes

        deps: List of labels of other rules that produce TypeScript typings (.d.ts files)

        tsconfig: Label of the tsconfig.json file to use for the compilation.
            To support "chaining" of more than one extended config, this label could be a target that
            provides `TsConfigInfo` such as `ts_config`.

            By default, if a "tsconfig.json" file is in the same folder with the ts_project rule, it is used.

            Instead of a label, you can pass a dictionary of tsconfig keys.
            In this case, a tsconfig.json file will be generated for this compilation, in the following way:
            - all top-level keys will be copied by converting the dict to json.
              So `tsconfig = {"compilerOptions": {"declaration": True}}`
              will result in a generated `tsconfig.json` with `{"compilerOptions": {"declaration": true}}`
            - each file in srcs will be converted to a relative path in the `files` section.
            - the `extends` attribute will be converted to a relative path
            Note that you can mix and match attributes and compilerOptions properties, so these are equivalent:
            ```
            ts_project(
                tsconfig = {
                    "compilerOptions": {
                        "declaration": True,
                    },
                },
            )
            ```
            and
            ```
            ts_project(
                declaration = True,
            )
            ```

        extends: Label of the tsconfig file referenced in the `extends` section of tsconfig
            To support "chaining" of more than one extended config, this label could be a target that
            provdes `TsConfigInfo` such as `ts_config`.

        args: List of strings of additional command-line arguments to pass to tsc.
            See https://www.typescriptlang.org/docs/handbook/compiler-options.html#compiler-options
            Typically useful arguments for debugging are `--listFiles` and `--listEmittedFiles`.

        transpiler: A custom transpiler tool to run that produces the JavaScript outputs instead of `tsc`.

            By default, `ts_project` expects `.js` outputs to be written in the same action
            that does the type-checking to produce `.d.ts` outputs.
            This is the simplest configuration, however `tsc` is slower than alternatives.
            It also means developers must wait for the type-checking in the developer loop.

            This attribute accepts a rule or macro with this signature:
            `name, srcs, js_outs, map_outs, **kwargs`
            where the `**kwargs` attribute propagates the tags, visibility, and testonly attributes from `ts_project`.
            If you need to pass additional attributes to the transpiler rule, you can use a
            [partial](https://github.com/bazelbuild/bazel-skylib/blob/main/lib/partial.bzl)
            to bind those arguments at the "make site", then pass that partial to this attribute where it
            will be called with the remaining arguments.
            See the packages/typescript/test/ts_project/swc directory for an example.

            When a custom transpiler is used, then the `ts_project` macro expands to these targets:

            - `[name]` - the default target which can be included in the `deps` of downstream rules.
                Note that it will successfully build *even if there are typecheck failures* because the `tsc` binary
                is not needed to produce the default outputs.
                This is considered a feature, as it allows you to have a faster development mode where type-checking
                is not on the critical path.
            - `[name]_typecheck` - provides typings (`.d.ts` files) as the default output,
               therefore building this target always causes the typechecker to run.
            - `[name]_typecheck_test` - a
               [`build_test`](https://github.com/bazelbuild/bazel-skylib/blob/main/rules/build_test.bzl)
               target which simply depends on the `[name]_typecheck` target.
               This ensures that typechecking will be run under `bazel test` with
               [`--build_tests_only`](https://docs.bazel.build/versions/main/user-manual.html#flag--build_tests_only).
            - `[name]_typings` - internal target which runs the binary from the `tsc` attribute
            -  Any additional target(s) the custom transpiler rule/macro produces.
                Some rules produce one target per TypeScript input file.

            Read more: https://blog.aspect.dev/typescript-speedup

        validate: Whether to check that the tsconfig JSON settings match the attributes on this target.
            Set this to `False` to skip running our validator, in case you have a legitimate reason for these to differ,
            e.g. you have a setting enabled just for the editor but you want different behavior when Bazel runs `tsc`.


        root_dir: String specifying a subdirectory under the input package which should be consider the
            root directory of all the input files.
            Equivalent to the TypeScript --rootDir option.
            By default it is '.', meaning the source directory where the BUILD file lives.

        out_dir: String specifying a subdirectory under the bazel-out folder where outputs are written.
            Equivalent to the TypeScript --outDir option.
            Note that Bazel always requires outputs be written under a subdirectory matching the input package,
            so if your rule appears in path/to/my/package/BUILD.bazel and out_dir = "foo" then the .js files
            will appear in bazel-out/[arch]/bin/path/to/my/package/foo/*.js.
            By default the out_dir is '.', meaning the packages folder in bazel-out.

        tsc: Label of the TypeScript compiler binary to run.
            This allows you to use a custom compiler.
        tsc_worker: Label of a custom TypeScript compiler binary which understands Bazel's persistent worker protocol.
        validator: Label of the tsconfig validator to run when `validate = True`.
        allow_js: Whether TypeScript will read .js and .jsx files.
            When used with `declaration`, TypeScript will generate `.d.ts` files from `.js` files.
        resolve_json_module: None | Boolean; Specifies whether TypeScript will read .json files. Defaults to None.
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
        emit_declaration_only: Whether the `emitDeclarationOnly` bit is set in the tsconfig.
            Instructs Bazel *not* to expect `.js` or `.js.map` outputs for `.ts` sources.
        ts_build_info_file: The user-specified value of `tsBuildInfoFile` from the tsconfig.
            Helps Bazel to predict the path where the .tsbuildinfo output is written.
        supports_workers: Whether the worker protocol is enabled.
            To disable worker mode for a particular target set `supports_workers` to `False`.
            Worker mode can be controlled as well via `--strategy` and `mnemonic` and  using .bazelrc.

            Putting this to your .bazelrc will disable it globally.

            ```
            build --strategy=TsProject=sandboxed
            ```

            Checkout https://docs.bazel.build/versions/main/user-manual.html#flag--strategy for more
        **kwargs: passed through to underlying [`ts_project_rule`](#ts_project_rule), eg. `visibility`, `tags`
    """

    # Disable workers if a custom tsc was provided but not a custom tsc_worker.
    if tsc != _tsc and tsc_worker == _tsc_worker:
        supports_workers = False

    if srcs == None:
        include = ["**/*.ts", "**/*.tsx"]
        exclude = []
        if allow_js == True:
            include.extend(["**/*.js", "**/*.jsx"])
        if resolve_json_module == True:
            include.append("**/*.json")
            exclude.extend(["**/package.json", "**/package-lock.json", "**/tsconfig*.json"])
        srcs = native.glob(include, exclude)
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
        # TODO: fail if compilerOptions includes a conflict with an attribute?
        compiler_options = tsconfig.setdefault("compilerOptions", {})
        source_map = compiler_options.setdefault("sourceMap", source_map)
        declaration = compiler_options.setdefault("declaration", declaration)
        declaration_map = compiler_options.setdefault("declarationMap", declaration_map)
        emit_declaration_only = compiler_options.setdefault("emitDeclarationOnly", emit_declaration_only)
        allow_js = compiler_options.setdefault("allowJs", allow_js)
        if resolve_json_module != None:
            resolve_json_module = compiler_options.setdefault("resolveJsonModule", resolve_json_module)

        # These options are always passed on the tsc command line so don't include them
        # in the tsconfig. At best they're redundant, but at worst we'll have a conflict
        if "outDir" in compiler_options.keys():
            out_dir = compiler_options.pop("outDir")
        if "declarationDir" in compiler_options.keys():
            declaration_dir = compiler_options.pop("declarationDir")
        if "rootDir" in compiler_options.keys():
            root_dir = compiler_options.pop("rootDir")

        # FIXME: need to remove keys that have a None value?
        write_tsconfig(
            name = "_gen_tsconfig_%s" % name,
            config = tsconfig,
            files = srcs,
            extends = Label("%s//%s:%s" % (native.repository_name(), native.package_name(), name)).relative(extends) if extends else None,
            out = "tsconfig_%s.json" % name,
            allow_js = allow_js,
            resolve_json_module = resolve_json_module,
        )

        # From here, tsconfig becomes a file, the same as if the
        # user supplied a tsconfig.json InputArtifact
        tsconfig = "tsconfig_%s.json" % name

    elif validate:
        validate_options(
            name = "_validate_%s_options" % name,
            target = "//%s:%s" % (native.package_name(), name),
            declaration = declaration,
            source_map = source_map,
            declaration_map = declaration_map,
            preserve_jsx = preserve_jsx,
            composite = composite,
            incremental = incremental,
            ts_build_info_file = ts_build_info_file,
            emit_declaration_only = emit_declaration_only,
            resolve_json_module = resolve_json_module,
            allow_js = allow_js,
            tsconfig = tsconfig,
            extends = extends,
            has_local_deps = len([d for d in deps if not is_external_label(d)]) > 0,
            validator = validator,
            **common_kwargs
        )
        tsc_deps = tsc_deps + ["_validate_%s_options" % name]

    typings_out_dir = declaration_dir if declaration_dir else out_dir
    tsbuildinfo_path = ts_build_info_file if ts_build_info_file else name + ".tsbuildinfo"

    js_outs = _lib.calculate_js_outs(srcs, out_dir, root_dir, allow_js, preserve_jsx, emit_declaration_only)
    map_outs = _lib.calculate_map_outs(srcs, out_dir, root_dir, source_map, preserve_jsx, emit_declaration_only)
    typings_outs = _lib.calculate_typings_outs(srcs, typings_out_dir, root_dir, declaration, composite, allow_js)
    typing_maps_outs = _lib.calculate_typing_maps_outs(srcs, typings_out_dir, root_dir, declaration_map, allow_js)

    tsc_js_outs = []
    tsc_map_outs = []
    if not transpiler:
        tsc_js_outs = js_outs
        tsc_map_outs = map_outs
        tsc_target_name = name
    else:
        # To stitch together a tree of ts_project where transpiler is a separate rule,
        # we have to produce a few targets
        tsc_target_name = "%s_typings" % name
        transpile_target_name = "%s_transpile" % name
        typecheck_target_name = "%s_typecheck" % name
        test_target_name = "%s_typecheck_test" % name

        transpile_srcs = [s for s in srcs if _lib.is_ts_src(s, allow_js)]
        if (len(transpile_srcs) != len(js_outs)):
            fail("ERROR: illegal state: transpile_srcs has length {} but js_outs has length {}".format(
                len(transpile_srcs),
                len(js_outs),
            ))

        if type(transpiler) == "function" or type(transpiler) == "rule":
            transpiler(
                name = transpile_target_name,
                srcs = transpile_srcs,
                js_outs = js_outs,
                map_outs = map_outs,
                **common_kwargs
            )
        elif partial.is_instance(transpiler):
            partial.call(
                transpiler,
                name = transpile_target_name,
                srcs = transpile_srcs,
                js_outs = js_outs,
                map_outs = map_outs,
                **common_kwargs
            )
        else:
            fail("transpiler attribute should be a rule/macro or a skylib partial. Got " + type(transpiler))

        # Users should build this target to get a failed build when typechecking fails
        native.filegroup(
            name = typecheck_target_name,
            srcs = [tsc_target_name],
            # This causes the declarations to be produced, which in turn triggers the tsc action to typecheck
            output_group = "types",
            **common_kwargs
        )

        # Ensures the typecheck target gets built under `bazel test --build_tests_only`
        build_test(
            name = test_target_name,
            targets = [typecheck_target_name],
            **common_kwargs
        )

        # Default target produced by the macro gives the js and map outs, with the transitive dependencies.
        js_library(
            name = name,
            # Include the tsc target in srcs to pick-up both the direct & transitive declaration outputs so
            # that this js_library can be a valid dep for downstream ts_project or other rules_js derivative rules.
            srcs = js_outs + map_outs + [tsc_target_name],
            deps = deps,
            **common_kwargs
        )

    ts_project_rule(
        name = tsc_target_name,
        srcs = srcs,
        args = args,
        data = data,
        deps = tsc_deps,
        tsconfig = tsconfig,
        allow_js = allow_js,
        extends = extends,
        incremental = incremental,
        preserve_jsx = preserve_jsx,
        composite = composite,
        declaration = declaration,
        declaration_dir = declaration_dir,
        source_map = source_map,
        declaration_map = declaration_map,
        out_dir = out_dir,
        root_dir = root_dir,
        js_outs = tsc_js_outs,
        map_outs = tsc_map_outs,
        typings_outs = typings_outs,
        typing_maps_outs = typing_maps_outs,
        buildinfo_out = tsbuildinfo_path if composite or incremental else None,
        emit_declaration_only = emit_declaration_only,
        tsc = tsc,
        tsc_worker = tsc_worker,
        transpile = not transpiler,
        supports_workers = supports_workers,
        **kwargs
    )
