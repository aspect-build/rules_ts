"""UnitTests for ts_lib output path calculation"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//ts/private:ts_lib.bzl", "lib")

# Cover typescript, jsx, module variants, typings, js, json, assets, label syntax and subdirectories
_SRCS = [
    "a.ts",
    "b.tsx",
    "sub/c.mts",
    "sub/d.cts",
    "e.d.ts",
    "typings.d.mts",
    "f.js",
    "g.jsx",
    "h.mjs",
    "i.cjs",
    "j.json",
    "k.css",
    ":l.ts",
    "sub/dir/m.ts",
]

def _outs_golden_test_impl(ctx):
    env = unittest.begin(ctx)

    # All emit types enabled: js+map+dts+dts.map with allow_js and resolve_json_module.
    # Note js/json srcs whose js out collides with the input (f.js -> f.js) are dropped.
    outs = lib.calculate_outs(
        srcs = _SRCS,
        out_dir = None,
        typings_out_dir = None,
        root_dir = None,
        allow_js = True,
        resolve_json_module = True,
        preserve_jsx = False,
        emit_declaration_only = False,
        source_map = True,
        declaration = True,
        composite = False,
        declaration_map = True,
        emit_js = True,
        emit_dts = True,
    )
    asserts.equals(env, ["a.js", "b.js", "sub/c.mjs", "sub/d.cjs", "g.js", "l.js", "sub/dir/m.js"], outs.js_outs)
    asserts.equals(env, ["a.js.map", "b.js.map", "sub/c.mjs.map", "sub/d.cjs.map", "f.js.map", "g.js.map", "h.mjs.map", "i.cjs.map", "l.js.map", "sub/dir/m.js.map"], outs.map_outs)
    asserts.equals(env, ["a.d.ts", "b.d.ts", "sub/c.d.mts", "sub/d.d.cts", "f.d.ts", "g.d.ts", "h.d.mts", "i.d.cts", "l.d.ts", "sub/dir/m.d.ts"], outs.typings_outs)
    asserts.equals(env, ["a.d.ts.map", "b.d.ts.map", "sub/c.d.mts.map", "sub/d.d.cts.map", "f.d.ts.map", "g.d.ts.map", "h.d.mts.map", "i.d.cts.map", "l.d.ts.map", "sub/dir/m.d.ts.map"], outs.typing_maps_outs)

    # out_dir, declaration_dir and root_dir remapping with preserve_jsx (no allow_js)
    outs = lib.calculate_outs(
        srcs = ["a.ts", "b.tsx", "sub/c.ts"],
        out_dir = "dist",
        typings_out_dir = "types",
        root_dir = "sub",
        allow_js = False,
        resolve_json_module = False,
        preserve_jsx = True,
        emit_declaration_only = False,
        source_map = True,
        declaration = True,
        composite = False,
        declaration_map = False,
        emit_js = True,
        emit_dts = True,
    )
    asserts.equals(env, ["dist/a.js", "dist/b.jsx", "dist/c.js"], outs.js_outs)
    asserts.equals(env, ["dist/a.js.map", "dist/b.jsx.map", "dist/c.js.map"], outs.map_outs)
    asserts.equals(env, ["types/a.d.ts", "types/b.d.ts", "types/c.d.ts"], outs.typings_outs)
    asserts.equals(env, [], outs.typing_maps_outs)

    # preserve_jsx with allow_js: .jsx srcs collide with their js out but still produce a map
    outs = lib.calculate_outs(
        srcs = _SRCS,
        out_dir = None,
        typings_out_dir = None,
        root_dir = None,
        allow_js = True,
        resolve_json_module = False,
        preserve_jsx = True,
        emit_declaration_only = False,
        source_map = True,
        declaration = False,
        composite = False,
        declaration_map = False,
        emit_js = True,
        emit_dts = False,
    )
    asserts.equals(env, ["a.js", "b.jsx", "sub/c.mjs", "sub/d.cjs", "l.js", "sub/dir/m.js"], outs.js_outs)
    asserts.equals(env, ["a.js.map", "b.jsx.map", "sub/c.mjs.map", "sub/d.cjs.map", "f.js.map", "g.jsx.map", "h.mjs.map", "i.cjs.map", "l.js.map", "sub/dir/m.js.map"], outs.map_outs)
    asserts.equals(env, [], outs.typings_outs)
    asserts.equals(env, [], outs.typing_maps_outs)

    # emit_declaration_only suppresses js+map outputs even when emit_js is set
    outs = lib.calculate_outs(
        srcs = _SRCS,
        out_dir = None,
        typings_out_dir = None,
        root_dir = None,
        allow_js = False,
        resolve_json_module = False,
        preserve_jsx = False,
        emit_declaration_only = True,
        source_map = True,
        declaration = True,
        composite = False,
        declaration_map = True,
        emit_js = True,
        emit_dts = True,
    )
    asserts.equals(env, [], outs.js_outs)
    asserts.equals(env, [], outs.map_outs)
    asserts.equals(env, ["a.d.ts", "b.d.ts", "sub/c.d.mts", "sub/d.d.cts", "l.d.ts", "sub/dir/m.d.ts"], outs.typings_outs)
    asserts.equals(env, ["a.d.ts.map", "b.d.ts.map", "sub/c.d.mts.map", "sub/d.d.cts.map", "l.d.ts.map", "sub/dir/m.d.ts.map"], outs.typing_maps_outs)

    # composite without declaration still emits typings; source_map off suppresses maps
    outs = lib.calculate_outs(
        srcs = _SRCS,
        out_dir = None,
        typings_out_dir = None,
        root_dir = None,
        allow_js = False,
        resolve_json_module = False,
        preserve_jsx = False,
        emit_declaration_only = False,
        source_map = False,
        declaration = False,
        composite = True,
        declaration_map = False,
        emit_js = True,
        emit_dts = True,
    )
    asserts.equals(env, ["a.js", "b.js", "sub/c.mjs", "sub/d.cjs", "l.js", "sub/dir/m.js"], outs.js_outs)
    asserts.equals(env, [], outs.map_outs)
    asserts.equals(env, ["a.d.ts", "b.d.ts", "sub/c.d.mts", "sub/d.d.cts", "l.d.ts", "sub/dir/m.d.ts"], outs.typings_outs)
    asserts.equals(env, [], outs.typing_maps_outs)

    # no_emit-style invocation produces nothing
    outs = lib.calculate_outs(
        srcs = _SRCS,
        out_dir = None,
        typings_out_dir = None,
        root_dir = None,
        allow_js = True,
        resolve_json_module = True,
        preserve_jsx = True,
        emit_declaration_only = False,
        source_map = True,
        declaration = True,
        composite = True,
        declaration_map = True,
        emit_js = False,
        emit_dts = False,
    )
    asserts.equals(env, [], outs.js_outs)
    asserts.equals(env, [], outs.map_outs)
    asserts.equals(env, [], outs.typings_outs)
    asserts.equals(env, [], outs.typing_maps_outs)

    return unittest.end(env)

_outs_golden_test = unittest.make(_outs_golden_test_impl)

def ts_lib_test_suite(name):
    """Test suite for ts_lib output calculation

    Args:
        name: name of the test suite target
    """
    unittest.suite(
        name,
        _outs_golden_test,
    )
