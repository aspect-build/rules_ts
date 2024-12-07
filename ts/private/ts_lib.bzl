"Utilities functions for selecting and filtering ts and other files"

# Attributes common to all TypeScript rules
STD_ATTRS = {
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
    ),
    "out_dir": attr.string(
        doc = "https://www.typescriptlang.org/tsconfig#outDir",
    ),
    "root_dir": attr.string(
        doc = "https://www.typescriptlang.org/tsconfig#rootDir",
    ),
    "srcs": attr.label_list(
        doc = "TypeScript source files and assets",
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
    "validator": attr.label(mandatory = True, executable = True, cfg = "exec"),
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
    "asset_outs": attr.output_list(
        doc = "Locations in bazel-out where ts_project will write asset files",
    ),
}

def _join(*elements):
    segments = [f for f in elements if f and f != "."]
    if len(segments):
        return "/".join(segments)
    return "."

def _relative_to_package(path, ctx):
    path = path.removeprefix(ctx.bin_dir.path + "/")
    path = path.removeprefix("external/")
    path = path.removeprefix(ctx.label.workspace_name + "/")
    if ctx.label.package:
        path = path.removeprefix(ctx.label.package + "/")
    return path

def _is_typings_src(src):
    return src.endswith(".d.ts") or src.endswith(".d.mts") or src.endswith(".d.cts")

def _is_js_src(src, allow_js):
    if allow_js and (src.endswith(".js") or src.endswith(".jsx") or src.endswith(".mjs") or src.endswith(".cjs")):
        return True
    return False

def _is_ts_src(src, allow_js, include_typings):
    if src.endswith(".ts") or src.endswith(".tsx") or src.endswith(".mts") or src.endswith(".cts"):
        return include_typings or not _is_typings_src(src)

    return _is_js_src(src, allow_js)

def _to_out_path(f, out_dir, root_dir):
    f = f[f.find(":") + 1:]
    if root_dir:
        f = f.removeprefix(root_dir + "/")
    if out_dir and out_dir != ".":
        f = out_dir + "/" + f
    return f

def _to_js_out_paths(srcs, out_dir, root_dir, allow_js, ext_map, default_ext):
    outs = []
    for f in srcs:
        if _is_ts_src(f, allow_js, False):
            out = _to_out_path(f, out_dir, root_dir)
            ext_idx = out.rindex(".")
            out = out[:ext_idx] + ext_map.get(out[ext_idx:], default_ext)

            # Don't declare outputs that collide with inputs
            # for example, a.js -> a.js
            if out != f:
                outs.append(out)
    return outs

# Macros can't reliably distinguish between labels and paths, but we can make a guess.
def _is_likely_label(f):
    return f.find(":") != -1 or f.startswith("//") or f.startswith("@")

def _calculate_asset_outs(srcs, out_dir, typings_out_dir, root_dir, allow_js):
    outs = []
    for f in srcs:
        # We must avoid predeclaring asset outputs for labels, because the label name is
        # not guaranteed to bear any relation to the actual names of the output assets.
        if not _is_ts_src(f, allow_js, False) and not _is_likely_label(f):
            out = _to_out_path(f, typings_out_dir if _is_typings_src(f) else out_dir, root_dir)
            # Don't declare outputs that collide with inputs
            if out != f:
                outs.append(out)
    return outs

# Quick check to validate path options
# One usecase: https://github.com/aspect-build/rules_ts/issues/551
def _validate_tsconfig_dirs(root_dir, out_dir, typings_out_dir):
    if root_dir and root_dir.find("../") != -1:
        fail("root_dir cannot access parent directories")

    if out_dir and out_dir.find("../") != -1:
        fail("out_dir cannot output to parent directory")

    if typings_out_dir and typings_out_dir.find("../") != -1:
        fail("typings_out_dir cannot output to parent directory")

def _calculate_js_outs(srcs, out_dir, root_dir, allow_js, preserve_jsx, emit_declaration_only):
    if emit_declaration_only:
        return []

    exts = {
        ".mts": ".mjs",
        ".mjs": ".mjs",
        ".cjs": ".cjs",
        ".cts": ".cjs",
    }

    if preserve_jsx:
        exts[".jsx"] = ".jsx"
        exts[".tsx"] = ".jsx"

    return _to_js_out_paths(srcs, out_dir, root_dir, allow_js, exts, ".js")

def _calculate_map_outs(srcs, out_dir, root_dir, source_map, preserve_jsx, emit_declaration_only):
    if not source_map or emit_declaration_only:
        return []

    exts = {
        ".mts": ".mjs.map",
        ".cts": ".cjs.map",
        ".mjs": ".mjs.map",
        ".cjs": ".cjs.map",
    }
    if preserve_jsx:
        exts[".tsx"] = ".jsx.map"

    return _to_js_out_paths(srcs, out_dir, root_dir, False, exts, ".js.map")

def _calculate_typings_outs(srcs, typings_out_dir, root_dir, declaration, composite, allow_js):
    if not (declaration or composite):
        return []

    exts = {
        ".mts": ".d.mts",
        ".cts": ".d.cts",
        ".mjs": ".d.mts",
        ".cjs": ".d.cts",
    }

    return _to_js_out_paths(srcs, typings_out_dir, root_dir, allow_js, exts, ".d.ts")

def _calculate_typing_maps_outs(srcs, typings_out_dir, root_dir, declaration_map, allow_js):
    if not declaration_map:
        return []

    exts = {
        ".mts": ".d.mts.map",
        ".cts": ".d.cts.map",
        ".mjs": ".d.mts.map",
        ".cjs": ".d.cts.map",
    }

    return _to_js_out_paths(srcs, typings_out_dir, root_dir, allow_js, exts, ".d.ts.map")

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
    out_paths = _to_js_out_paths,
    to_out_path = _to_out_path,
    validate_tsconfig_dirs = _validate_tsconfig_dirs,
    calculate_js_outs = _calculate_js_outs,
    calculate_map_outs = _calculate_map_outs,
    calculate_typings_outs = _calculate_typings_outs,
    calculate_typing_maps_outs = _calculate_typing_maps_outs,
    calculate_asset_outs = _calculate_asset_outs,
    calculate_root_dir = _calculate_root_dir,
)
