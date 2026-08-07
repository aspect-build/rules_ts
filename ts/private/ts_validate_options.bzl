"Helper rule to check that ts_project attributes match tsconfig.json properties"

load("@aspect_rules_js//js:libs.bzl", "js_binary_lib")
load("@bazel_lib//lib:paths.bzl", "to_output_relative_path")
load(":ts_lib.bzl", _lib = "lib")

def _validate_action(ctx, tsconfig, tsconfig_deps):
    """Create an action to validate the ts_project attributes against the tsconfig.json properties.

The validator invokes the equivalent of `tsc --showConfig` programmatically to flatten
the tsconfig "extends" chain, checks the attributes against the resolved config, and
writes the resolved config as the validation output.

Assumes all tsconfig file deps are already copied to the bin directory.
"""
    resolved = ctx.actions.declare_file("%s.resolved.tsconfig.json" % ctx.label.name)

    arguments = ctx.actions.args()
    config = struct(
        allow_js = ctx.attr.allow_js,
        declaration = ctx.attr.declaration,
        declaration_dir = ctx.attr.declaration_dir,
        declaration_map = ctx.attr.declaration_map,
        out_dir = ctx.attr.out_dir,
        preserve_jsx = ctx.attr.preserve_jsx,
        composite = ctx.attr.composite,
        no_emit = ctx.attr.no_emit,
        emit_declaration_only = ctx.attr.emit_declaration_only,
        resolve_json_module = ctx.attr.resolve_json_module,
        source_map = ctx.attr.source_map,
        incremental = ctx.attr.incremental,
        ts_build_info_file = ctx.attr.ts_build_info_file,
        isolated_typecheck = ctx.attr.isolated_typecheck,
        root_dir = ctx.attr.root_dir,
    )
    arguments.add_all([
        to_output_relative_path(tsconfig),
        to_output_relative_path(resolved),
        str(ctx.label),
        _lib.join(ctx.label.workspace_root, ctx.label.package),
        json.encode(config),
    ])

    js_binary_lib.run_binary_action(
        ctx = ctx,
        executable = ctx.executable.validator,
        inputs = tsconfig_deps,
        outputs = [resolved],
        arguments = [arguments],
        mnemonic = "TsValidateOptions",
        execution_requirements = {"supports-path-mapping": "1"},
        use_default_shell_env = True,
    )

    return [resolved]

lib = struct(
    validation_action = _validate_action,
)
