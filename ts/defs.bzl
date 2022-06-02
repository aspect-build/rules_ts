"""Public API for TypeScript rules

Nearly identical to the ts_project wrapper macro in npm @bazel/typescript.
Differences:
- doesn't have worker support
- uses the executables from @npm_typescript rather than what a user npm_install'ed
- didn't copy the whole doc string
"""

load("@aspect_bazel_lib//lib:utils.bzl", "is_external_label", "to_label")
load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//ts/private:ts_config.bzl", "write_tsconfig", _ts_config = "ts_config")
load("//ts/private:ts_declaration.bzl", "ts_declaration")
load("//ts/private:ts_project.bzl", _ts_project_lib = "ts_project")
load("//ts/private:ts_validate_options.bzl", validate_lib = "lib")
load("//ts/private:ts_lib.bzl", _lib = "lib")

ts_config = _ts_config

validate_options = rule(
    implementation = validate_lib.implementation,
    attrs = validate_lib.attrs,
)

_ts_project = rule(
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

# buildifier: disable=function-docstring-args
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
        tsc = "@npm_typescript//:tsc",
        validate = True,
        validator = "@npm_typescript//:validator",
        declaration_dir = None,
        out_dir = None,
        root_dir = None,
        **kwargs):
    """Compiles one TypeScript project using `tsc --project`.

    For the list of args, see the ts_project rule.
    """

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
            # This causes the DeclarationInfo to be produced, which in turn triggers the tsc action to typecheck
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
        ts_declaration(
            name = name,
            srcs = js_outs + map_outs,
            # Include the tsc target so that this js_library can be a valid dep for downstream ts_project
            # or other DeclarationInfo-aware rules.
            deps = deps + [tsc_target_name],
            **common_kwargs
        )

    _ts_project(
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
        transpile = not transpiler,
        # We don't support this feature at all from rules_nodejs yet
        supports_workers = False,
        **kwargs
    )
