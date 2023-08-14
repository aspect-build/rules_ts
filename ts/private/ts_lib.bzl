"Utilities functions for selecting and filtering ts and other files"

load("@aspect_rules_js//js:providers.bzl", "JsInfo")
load("@aspect_rules_js//js:libs.bzl", "js_lib_helpers")

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
    "data": js_lib_helpers.JS_LIBRARY_DATA_ATTR,
    "declaration_dir": attr.string(
        doc = "https://www.typescriptlang.org/tsconfig#declarationDir",
    ),
    "deps": attr.label_list(
        doc = """List of targets that produce TypeScript typings (`.d.ts` files)

{downstream_linked_npm_deps}
""".format(downstream_linked_npm_deps = js_lib_helpers.DOWNSTREAM_LINKED_NPM_DEPS_DOCSTRING),
        providers = [JsInfo],
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
    "supports_workers": attr.int(
        doc = """\
        Whether to use a custom `tsc` compiler which understands Bazel's persistent worker protocol.

        See the docs for `supports_workers` on the [`ts_project`](#ts_project-supports_workers) macro.
        """,
        default = 0,
        values = [-1, 0, 1],
    ),
    "is_typescript_5_or_greater": attr.bool(
        doc = "Whether TypeScript version is >= 5.0.0",
        default = False,
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
    "tsc": attr.label(
        doc = "TypeScript compiler binary",
        mandatory = True,
        executable = True,
        cfg = "exec",
    ),
    "tsc_worker": attr.label(
        doc = "TypeScript compiler worker binary",
        mandatory = True,
        executable = True,
        cfg = "exec",
    ),
    "tsconfig": attr.label(
        doc = "tsconfig.json file, see https://www.typescriptlang.org/tsconfig",
        mandatory = True,
        allow_single_file = [".json"],
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
    "emit_declaration_only": attr.bool(
        doc = "https://www.typescriptlang.org/tsconfig#emitDeclarationOnly",
    ),
    "extends": attr.label(
        allow_files = [".json"],
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

def _strip_external(path):
    return path[len("external/"):] if path.startswith("external/") else path

def _relative_to_package(path, ctx):
    for prefix in [ctx.bin_dir.path, ctx.label.workspace_name, ctx.label.package]:
        prefix += "/"
        path = _strip_external(path)
        if path.startswith(prefix):
            path = path[len(prefix):]
    return path

def _is_typings_src(src):
    return src.endswith(".d.ts") or src.endswith(".d.mts") or src.endswith(".d.cts")

def _is_js_src(src, allow_js, resolve_json_module):
    if src.endswith(".js") or src.endswith(".jsx") or src.endswith(".mjs") or src.endswith(".cjs"):
        return allow_js

    if src.endswith(".json"):
        return resolve_json_module

    return False

def _is_ts_src(src, allow_js, resolve_json_module):
    if (src.endswith(".ts") or src.endswith(".tsx") or src.endswith(".mts") or src.endswith(".cts")):
        return not _is_typings_src(src)

    return _is_js_src(src, allow_js, resolve_json_module)

def _replace_ext(f, ext_map):
    cur_ext = f[f.rindex("."):]
    new_ext = ext_map.get(cur_ext)
    if new_ext != None:
        return new_ext
    new_ext = ext_map.get("*")
    if new_ext != None:
        return new_ext
    return None

def _out_paths(srcs, out_dir, root_dir, allow_js, resolve_json_module, ext_map):
    rootdir_replace_pattern = root_dir + "/" if root_dir else ""
    outs = []
    for f in srcs:
        if _is_ts_src(f, allow_js, resolve_json_module):
            out = _join(out_dir, f[:f.rindex(".")].replace(rootdir_replace_pattern, "", 1) + _replace_ext(f, ext_map))

            # Don't declare outputs that collide with inputs
            # for example, a.js -> a.js
            if out != f:
                outs.append(out)
    return outs

def _calculate_js_outs(srcs, out_dir = ".", root_dir = ".", allow_js = False, resolve_json_module = False, preserve_jsx = False, emit_declaration_only = False):
    if emit_declaration_only:
        return []

    exts = {
        "*": ".js",
        ".mts": ".mjs",
        ".mjs": ".mjs",
        ".cjs": ".cjs",
        ".cts": ".cjs",
        ".json": ".json",
    }

    if preserve_jsx:
        exts[".jsx"] = ".jsx"
        exts[".tsx"] = ".jsx"

    return _out_paths(srcs, out_dir, root_dir, allow_js, resolve_json_module, exts)

def _calculate_map_outs(srcs, out_dir = ".", root_dir = ".", source_map = True, preserve_jsx = False, emit_declaration_only = False):
    if not source_map or emit_declaration_only:
        return []

    exts = {
        "*": ".js.map",
        ".mts": ".mjs.map",
        ".cts": ".cjs.map",
        ".mjs": ".mjs.map",
        ".cjs": ".cjs.map",
    }
    if preserve_jsx:
        exts[".tsx"] = ".jsx.map"

    return _out_paths(srcs, out_dir, root_dir, False, False, exts)

def _calculate_typings_outs(srcs, typings_out_dir, root_dir, declaration, composite, allow_js):
    if not (declaration or composite):
        return []

    exts = {
        "*": ".d.ts",
        ".mts": ".d.mts",
        ".cts": ".d.cts",
        ".mjs": ".d.mts",
        ".cjs": ".d.cts",
    }

    return _out_paths(srcs, typings_out_dir, root_dir, allow_js, False, exts)

def _calculate_typing_maps_outs(srcs, typings_out_dir, root_dir, declaration_map, allow_js):
    if not declaration_map:
        return []

    exts = {
        "*": ".d.ts.map",
        ".mts": ".d.mts.map",
        ".cts": ".d.cts.map",
        ".mjs": ".d.mts.map",
        ".cjs": ".d.cts.map",
    }

    return _out_paths(srcs, typings_out_dir, root_dir, allow_js, False, exts)

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
    relative_to_package = _relative_to_package,
    is_typings_src = _is_typings_src,
    is_ts_src = _is_ts_src,
    is_js_src = _is_js_src,
    out_paths = _out_paths,
    calculate_js_outs = _calculate_js_outs,
    calculate_map_outs = _calculate_map_outs,
    calculate_typings_outs = _calculate_typings_outs,
    calculate_typing_maps_outs = _calculate_typing_maps_outs,
    calculate_root_dir = _calculate_root_dir,
)
