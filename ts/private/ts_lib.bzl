"Utilities functions for selecting and filtering ts and other files"

load("@aspect_rules_js//js:providers.bzl", "JsInfo")

# Attributes common to all TypeScript rules
STD_ATTRS = {
    "assets": attr.label_list(
        doc = """Files which are needed by a downstream build step such as a bundler.

See more details on the `assets` parameter of the `ts_project` macro.
""",
        allow_files = True,
    ),
    "args": attr.string_list(
        doc = "https://www.typescriptlang.org/docs/handbook/compiler-options.html",
    ),
    "data": attr.label_list(
        doc = """Runtime dependencies to include in binaries/tests that depend on this target.

Follows the same semantics as `js_library` `data` attribute. See
https://docs.aspect.build/rulesets/aspect_rules_js/docs/js_library#data for more info.
""",
        allow_files = True,
    ),
    "declaration_dir": attr.string(
        doc = "https://www.typescriptlang.org/tsconfig#declarationDir",
    ),
    "deps": attr.label_list(
        doc = """List of targets that produce TypeScript typings (`.d.ts` files)

Follows the same runfiles semantics as `js_library` `deps` attribute. See
https://docs.aspect.build/rulesets/aspect_rules_js/docs/js_library#deps for more info.
""",
        providers = [JsInfo],  # Same as js_library(deps)
    ),
    "out_dir": attr.string(
        doc = "https://www.typescriptlang.org/tsconfig#outDir",
    ),
    "root_dir": attr.string(
        doc = "https://www.typescriptlang.org/tsconfig#rootDir",
    ),
    # NB: no restriction on extensions here, because tsc sometimes adds type-check support
    # for more file kinds (like require('some.json')) and also
    # if you swap out the `compiler` attribute (like with ngtsc)
    # that compiler might allow more sources than tsc does.
    "srcs": attr.label_list(
        doc = "TypeScript source files",
        allow_files = True,
        mandatory = True,
    ),
    "transpile": attr.int(
        doc = """\
        Whether tsc should be used to produce .js outputs

        Values are:
        - -1: Error if --@aspect_rules_ts//ts:default_to_tsc_transpiler not set, otherwise transpile
        - 0: Do not transpile
        - 1: Transpile
        """,
        default = -1,
        values = [-1, 0, 1],
    ),
    "pretranspiled_js": attr.label(
        doc = "Externally transpiled .js to be included in output providers",
    ),
    "pretranspiled_dts": attr.label(
        doc = "Externally transpiled .d.ts to be included in output providers",
    ),
    "declaration_transpile": attr.bool(
        doc = "Whether tsc should be used to produce .d.ts outputs",
    ),
    "tsc": attr.label(
        doc = "TypeScript compiler binary",
        mandatory = True,
        executable = True,
        cfg = "exec",
    ),
    "tsconfig": attr.label(
        doc = "tsconfig.json file, see https://www.typescriptlang.org/tsconfig",
        mandatory = True,
        allow_single_file = [".json"],
    ),
    "eslintconfig": attr.label(
        doc = """.eslintrc file, or other filenames accepted by ESLint.
        see https://eslint.org/docs/latest/use/configure/configuration-files
        Note, this is unused in rules_ts, but exists to allow the information to propagate through the dependency graph.
        For example, it can be used by the eslint aspect in Aspect's rules_lint.
        """,
        allow_single_file = True,
    ),
    "isolated_typecheck": attr.bool(
        doc = """\
        Whether type-checking should be a separate action.

        This allows the transpilation action to run without waiting for typings from dependencies.

        Requires a minimum version of typescript 5.6 for the [noCheck](https://www.typescriptlang.org/tsconfig#noCheck)
        flag which is automatically set on the transpilation action when the typecheck action is isolated.

        Requires [isolatedDeclarations](https://www.typescriptlang.org/tsconfig#isolatedDeclarations)
        to be set so that declarations can be emitted without dependencies. The use of `isolatedDeclarations` may
        require significant changes to your codebase and should be done as a pre-requisite to enabling `isolated_typecheck`.
        """,
    ),
    "validate": attr.bool(
        doc = """whether to add a Validation Action to verify the other attributes match
            settings in the tsconfig.json file""",
        default = True,
    ),
    "build_progress_message": attr.string(
        doc = """\
            Custom progress message for the build action.
            You can use {label} and {tsconfig_path} as substitutions.
        """,
        default = "Transpiling{emit_part}{type_check_part} TypeScript project {label} [tsc -p {tsconfig_path}]",
    ),
    "isolated_typecheck_progress_message": attr.string(
        doc = """\
            Custom progress message for the isolated typecheck action.
            You can use {label} and {tsconfig_path} as substitutions.
        """,
        default = "Type-checking TypeScript project {label} [tsc -p {tsconfig_path}]",
    ),
    "_validation_tsc": attr.label(
        doc = """The default tsc, resolving the tsconfig for validation (`tsc --showConfig`)
        regardless of the `tsc` attribute, which may be a custom compiler without `--showConfig` support.""",
        default = "@npm_typescript//:tsc",
        executable = True,
        cfg = "exec",
    ),
    "_validator": attr.label(
        doc = "Script comparing the resolved tsconfig with the ts_project attributes.",
        allow_single_file = True,
        default = "@aspect_rules_ts//ts/private:ts_project_options_validator.sh",
    ),
    "_options": attr.label(
        default = "@aspect_rules_ts//ts:options",
    ),
}

# These attrs are shared between the validate and the ts_project rules
# They simply mirror data from the compilerOptions block in tsconfig.json
# so that Bazel can predict all of tsc's outputs.
COMPILER_OPTION_ATTRS = {
    "allow_js": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#allowJs",
    ),
    "composite": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#composite",
    ),
    "declaration": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#declaration",
    ),
    "declaration_map": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#declarationMap",
    ),
    "no_emit": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#noEmit",
    ),
    "emit_declaration_only": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#emitDeclarationOnly",
    ),
    "extends": attr.label(
        allow_files = True,
        doc = "https://www.typescriptlang.org/tsconfig#extends",
    ),
    "incremental": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#incremental",
    ),
    "preserve_jsx": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#jsx",
    ),
    "resolve_json_module": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#resolveJsonModule",
    ),
    "source_map": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#sourceMap",
    ),
    "ts_build_info_file": attr.string(
        doc = "https://www.typescriptlang.org/tsconfig#tsBuildInfoFile",
    ),
    "generate_trace": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig/#generateTrace",
    ),
}

# tsc knows how to produce the following kinds of output files.
# NB: the macro `ts_project_macro` will set these outputs based on user
# telling us which settings are enabled in the tsconfig for this project.
OUTPUT_ATTRS = {
    "buildinfo_out": attr.output(
        doc = "Location in bazel-out where tsc will write a `.tsbuildinfo` file",
    ),
    "js_outs": attr.output_list(
        doc = "Locations in bazel-out where tsc will write `.js` files",
    ),
    "map_outs": attr.output_list(
        doc = "Locations in bazel-out where tsc will write `.js.map` files",
    ),
    "typing_maps_outs": attr.output_list(
        doc = "Locations in bazel-out where tsc will write `.d.ts.map` files",
    ),
    "typings_outs": attr.output_list(
        doc = "Locations in bazel-out where tsc will write `.d.ts` files",
    ),
}

def _join(*elements):
    segments = [f for f in elements if f and f != "."]
    if len(segments):
        return "/".join(segments)
    return "."

def _files_relative_to_package(ctx, files):
    """Package-relative paths for a list of files, computing the prefixes only once."""
    bin_dir_prefix = ctx.bin_dir.path + "/"
    workspace_prefix = ctx.label.workspace_name + "/"
    package_prefix = ctx.label.package + "/" if ctx.label.package else None

    paths = []
    for file in files:
        path = file.path.removeprefix(bin_dir_prefix)
        path = path.removeprefix("external/")
        path = path.removeprefix(workspace_prefix)
        if package_prefix:
            path = path.removeprefix(package_prefix)
        paths.append(path)
    return paths

_TYPINGS_EXTS = (".d.ts", ".d.mts", ".d.cts")
_JS_EXTS = (".js", ".jsx", ".mjs", ".cjs")
_TS_EXTS = (".ts", ".tsx", ".mts", ".cts")

def _is_typings_src(src):
    return src.endswith(_TYPINGS_EXTS)

def _is_js_src(src, allow_js, resolve_json_module):
    if allow_js and src.endswith(_JS_EXTS):
        return True

    if resolve_json_module and src.endswith(".json"):
        return True

    return False

def _is_ts_src(src, allow_js, resolve_json_module, include_typings):
    if src.endswith(_TS_EXTS):
        return include_typings or not _is_typings_src(src)

    return _is_js_src(src, allow_js, resolve_json_module)

def _to_out_path(f, out_dir, root_dir):
    f = f[f.find(":") + 1:]

    if out_dir and f.startswith(out_dir + "/"):
        return f

    if root_dir:
        f = f.removeprefix(root_dir + "/")
    if out_dir:
        f = out_dir + "/" + f
    return f

# Quick check to validate path options
# One usecase: https://github.com/aspect-build/rules_ts/issues/551
def _validate_tsconfig_dirs(root_dir, out_dir, typings_out_dir):
    if root_dir and root_dir.find("../") != -1:
        fail("root_dir cannot access parent directories")

    if out_dir and out_dir.find("../") != -1:
        fail("out_dir cannot output to parent directory")

    if typings_out_dir and typings_out_dir.find("../") != -1:
        fail("typings_out_dir cannot output to parent directory")

def _with_jsx_exts(exts, jsx_out_ext):
    d = dict(exts)
    d[".jsx"] = jsx_out_ext
    d[".tsx"] = jsx_out_ext
    return d

# Maps of src extension -> output extension for each emit type. The _PRESERVE_JSX
# variants additionally map .jsx/.tsx to jsx outputs. Note that .jsx srcs only pass
# _is_ts_src when allow_js is set, so unused entries are harmless.
_JS_OUT_EXTS = {
    ".mts": ".mjs",
    ".mjs": ".mjs",
    ".cjs": ".cjs",
    ".cts": ".cjs",
    ".json": ".json",
}
_JS_OUT_EXTS_PRESERVE_JSX = _with_jsx_exts(_JS_OUT_EXTS, ".jsx")
_MAP_OUT_EXTS = {
    ".mts": ".mjs.map",
    ".cts": ".cjs.map",
    ".mjs": ".mjs.map",
    ".cjs": ".cjs.map",
}
_MAP_OUT_EXTS_PRESERVE_JSX = _with_jsx_exts(_MAP_OUT_EXTS, ".jsx.map")
_DTS_OUT_EXTS = {
    ".mts": ".d.mts",
    ".cts": ".d.cts",
    ".mjs": ".d.mts",
    ".cjs": ".d.cts",
}
_DTS_MAP_OUT_EXTS = {
    ".mts": ".d.mts.map",
    ".cts": ".d.cts.map",
    ".mjs": ".d.mts.map",
    ".cjs": ".d.cts.map",
}

def _calculate_outs(
        srcs,
        out_dir,
        typings_out_dir,
        root_dir,
        allow_js,
        resolve_json_module,
        preserve_jsx,
        emit_declaration_only,
        source_map,
        declaration,
        composite,
        declaration_map,
        emit_js,
        emit_dts):
    """Calculate js, map, typings and typing map output paths in a single pass over srcs.

    Args:
        srcs: list of source path strings, relative to the package
        out_dir: `out_dir` attribute of ts_project
        typings_out_dir: `declaration_dir` attribute of ts_project, falling back to `out_dir`
        root_dir: `root_dir` attribute of ts_project
        allow_js: `allow_js` attribute of ts_project
        resolve_json_module: `resolve_json_module` attribute of ts_project
        preserve_jsx: `preserve_jsx` attribute of ts_project
        emit_declaration_only: `emit_declaration_only` attribute of ts_project
        source_map: `source_map` attribute of ts_project
        declaration: `declaration` attribute of ts_project
        composite: `composite` attribute of ts_project
        declaration_map: `declaration_map` attribute of ts_project
        emit_js: whether tsc emits js (and source map) outputs for this target
        emit_dts: whether tsc emits declaration (and declaration map) outputs for this target

    Returns:
        struct with js_outs, map_outs, typings_outs and typing_maps_outs path lists
    """
    want_js = emit_js and not emit_declaration_only
    want_map = want_js and source_map
    want_dts = emit_dts and (declaration or composite)
    want_dts_map = emit_dts and declaration_map

    js_outs = []
    map_outs = []
    typings_outs = []
    typing_maps_outs = []

    if not (want_js or want_dts or want_dts_map):
        return struct(js_outs = js_outs, map_outs = map_outs, typings_outs = typings_outs, typing_maps_outs = typing_maps_outs)

    js_exts = _JS_OUT_EXTS_PRESERVE_JSX if preserve_jsx else _JS_OUT_EXTS
    map_exts = _MAP_OUT_EXTS_PRESERVE_JSX if preserve_jsx else _MAP_OUT_EXTS
    same_out_dirs = typings_out_dir == out_dir

    for f in srcs:
        is_ts = _is_ts_src(f, allow_js, False, False)
        is_json = want_js and resolve_json_module and f.endswith(".json")
        if not is_ts and not is_json:
            continue

        out = None
        if want_js or (want_map and is_ts):
            out = _to_out_path(f, out_dir, root_dir)
            ext_idx = out.rindex(".")
            if want_js:
                js_out = out[:ext_idx] + js_exts.get(out[ext_idx:], ".js")

                # Don't declare outputs that collide with inputs
                # for example, a.js -> a.js
                if js_out != f:
                    js_outs.append(js_out)
            if want_map and is_ts:
                map_out = out[:ext_idx] + map_exts.get(out[ext_idx:], ".js.map")
                if map_out != f:
                    map_outs.append(map_out)

        if (want_dts or want_dts_map) and is_ts:
            t_out = out if (same_out_dirs and out != None) else _to_out_path(f, typings_out_dir, root_dir)
            ext_idx = t_out.rindex(".")
            if want_dts:
                dts_out = t_out[:ext_idx] + _DTS_OUT_EXTS.get(t_out[ext_idx:], ".d.ts")
                if dts_out != f:
                    typings_outs.append(dts_out)
            if want_dts_map:
                dts_map_out = t_out[:ext_idx] + _DTS_MAP_OUT_EXTS.get(t_out[ext_idx:], ".d.ts.map")
                if dts_map_out != f:
                    typing_maps_outs.append(dts_map_out)

    return struct(js_outs = js_outs, map_outs = map_outs, typings_outs = typings_outs, typing_maps_outs = typing_maps_outs)

def _calculate_root_dir(ctx):
    return _join(
        ctx.label.workspace_root,
        ctx.label.package,
        ctx.attr.root_dir,
    )

def _declare_outputs(ctx, paths):
    return [
        ctx.actions.declare_file(path)
        for path in paths
    ]

lib = struct(
    declare_outputs = _declare_outputs,
    join = _join,
    files_relative_to_package = _files_relative_to_package,
    is_typings_src = _is_typings_src,
    is_ts_src = _is_ts_src,
    is_js_src = _is_js_src,
    to_out_path = _to_out_path,
    validate_tsconfig_dirs = _validate_tsconfig_dirs,
    calculate_outs = _calculate_outs,
    calculate_root_dir = _calculate_root_dir,
)
