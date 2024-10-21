"ts_project rule"

load("@aspect_bazel_lib//lib:copy_file.bzl", "copy_file_action")
load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "COPY_FILE_TO_BIN_TOOLCHAINS", "copy_file_to_bin_action", "copy_files_to_bin_actions")
load("@aspect_bazel_lib//lib:paths.bzl", "to_output_relative_path")
load("@aspect_bazel_lib//lib:platform_utils.bzl", "platform_utils")
load("@aspect_bazel_lib//lib:resource_sets.bzl", "resource_set", "resource_set_attr")
load("@aspect_rules_js//js:libs.bzl", "js_lib_helpers")
load("@aspect_rules_js//js:providers.bzl", "JsInfo", "js_info")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(":options.bzl", "OptionsInfo", "transpiler_selection_required")
load(":ts_config.bzl", "TsConfigInfo")
load(":ts_lib.bzl", "COMPILER_OPTION_ATTRS", "OUTPUT_ATTRS", "STD_ATTRS", _lib = "lib")
load(":ts_validate_options.bzl", _validate_lib = "lib")

# Forked from js_lib_helpers.js_lib_helpers.gather_files_from_js_providers to not
# include any sources; only transitive types & npm sources
def _gather_types_from_js_infos(targets):
    files_depsets = []
    files_depsets.extend([
        target[JsInfo].transitive_types
        for target in targets
        if JsInfo in target
    ])
    files_depsets.extend([
        target[JsInfo].npm_sources
        for target in targets
        if JsInfo in target
    ])
    return depset([], transitive = files_depsets)

def _ts_project_impl(ctx):
    """Creates the action which spawns `tsc`.

    This function has two extra arguments that are particular to how it's called
    within build_bazel_rules_nodejs and @bazel/typescript npm package.
    Other TS rule implementations wouldn't need to pass these:

    Args:
        ctx: starlark rule execution context

    Returns:
        list of providers
    """
    options = ctx.attr._options[OptionsInfo]
    srcs_inputs = copy_files_to_bin_actions(ctx, ctx.files.srcs)
    tsconfig = copy_file_to_bin_action(ctx, ctx.file.tsconfig)

    # Gather TsConfig info from both the direct (tsconfig) and indirect (extends) attribute
    tsconfig_inputs = copy_files_to_bin_actions(ctx, _validate_lib.tsconfig_inputs(ctx).to_list())
    tsconfig_transitive_deps = [
        dep[TsConfigInfo].deps
        for dep in ctx.attr.deps
        if TsConfigInfo in dep
    ]

    srcs = [_lib.relative_to_package(src.path, ctx) for src in srcs_inputs]

    # Recalculate outputs inside the rule implementation.
    # The outs are first calculated in the macro in order to try to predetermine outputs so they can be declared as
    # outputs on the rule. This provides the benefit of being able to reference an output file with a label.
    # However, it is not possible to evaluate files in outputs of other rules such as filegroup, therefore the outs are
    # recalculated here.
    typings_out_dir = ctx.attr.declaration_dir or ctx.attr.out_dir

    # js+map file outputs
    js_outs = []
    map_outs = []
    if not ctx.attr.no_emit and ctx.attr.transpile != 0:
        js_outs = _lib.declare_outputs(ctx, _lib.calculate_js_outs(srcs, ctx.attr.out_dir, ctx.attr.root_dir, ctx.attr.allow_js, ctx.attr.resolve_json_module, ctx.attr.preserve_jsx, ctx.attr.emit_declaration_only))
        map_outs = _lib.declare_outputs(ctx, _lib.calculate_map_outs(srcs, ctx.attr.out_dir, ctx.attr.root_dir, ctx.attr.source_map, ctx.attr.preserve_jsx, ctx.attr.emit_declaration_only))

    # dts+map file outputs
    typings_outs = []
    typing_maps_outs = []
    if not ctx.attr.no_emit and not ctx.attr.declaration_transpile:
        typings_outs = _lib.declare_outputs(ctx, _lib.calculate_typings_outs(srcs, typings_out_dir, ctx.attr.root_dir, ctx.attr.declaration, ctx.attr.composite, ctx.attr.allow_js))
        typing_maps_outs = _lib.declare_outputs(ctx, _lib.calculate_typing_maps_outs(srcs, typings_out_dir, ctx.attr.root_dir, ctx.attr.declaration_map, ctx.attr.allow_js))

    validation_outs = []
    if ctx.attr.validate:
        validation_outs.extend(_validate_lib.validation_action(ctx, tsconfig_inputs))
        _lib.validate_tsconfig_dirs(ctx.attr.root_dir, ctx.attr.out_dir, typings_out_dir)

    typecheck_outs = []

    execution_requirements = {}
    executable = ctx.executable.tsc

    supports_workers = options.supports_workers
    if ctx.attr.supports_workers == 1:
        supports_workers = True
    elif ctx.attr.supports_workers == 0:
        supports_workers = False

    host_is_windows = platform_utils.host_platform_is_windows()
    if host_is_windows and supports_workers:
        supports_workers = False

        # buildifier: disable=print
        print("""\
WARNING: disabling ts_project workers which are not currently supported on Windows hosts.
See https://github.com/aspect-build/rules_ts/issues/228 for more details.
""")

    if ctx.attr.is_typescript_5_or_greater and supports_workers:
        supports_workers = False

        # buildifier: disable=print
        print("""\
WARNING: disabling ts_project workers which are not currently supported with TS >= 5.0.0.
See https://github.com/aspect-build/rules_ts/issues/361 for more details.
""")

    if supports_workers:
        execution_requirements["supports-workers"] = "1"
        execution_requirements["worker-key-mnemonic"] = "TsProject"
        executable = ctx.executable.tsc_worker

    common_args = []

    # Add all arguments from options first to allow users override them via args.
    common_args.extend(options.args)

    # Add user specified arguments *before* rule supplied arguments
    common_args.extend(ctx.attr.args)

    if (ctx.attr.out_dir and ctx.attr.out_dir != ".") or ctx.attr.root_dir:
        # TODO: add validation that excludes is non-empty in this case, as passing the --outDir or --declarationDir flag
        # to TypeScript causes it to set a default for excludes such that it won't find our sources that were copied-to-bin.
        # See https://github.com/microsoft/TypeScript/issues/59036 and https://github.com/aspect-build/rules_ts/issues/644
        common_args.extend([
            "--outDir",
            _lib.join(ctx.label.workspace_root, ctx.label.package, ctx.attr.out_dir),
        ])

        if len(typings_outs) > 0:
            common_args.extend([
                "--declarationDir",
                _lib.join(ctx.label.workspace_root, ctx.label.package, typings_out_dir),
            ])

    tsconfig_path = to_output_relative_path(tsconfig)
    common_args.extend([
        "--project",
        tsconfig_path,
        "--rootDir",
        _lib.calculate_root_dir(ctx),
    ])

    inputs = srcs_inputs + tsconfig_inputs

    transitive_inputs = []
    if ctx.attr.composite:
        # When TypeScript builds a composite project, our compilation will want to read the tsconfig.json of
        # composite projects we reference.
        # Otherwise we'd get an error like
        # examples/project_references/lib_b/tsconfig.json(5,9): error TS6053:
        # File 'execroot/aspect_rules_ts/bazel-out/k8-fastbuild/bin/examples/project_references/lib_a/tsconfig.json' not found.
        transitive_inputs.extend(tsconfig_transitive_deps)

    assets_outs = []
    for a in ctx.files.assets:
        a_path = _lib.relative_to_package(a.short_path, ctx)
        a_out = _lib.to_out_path(a_path, ctx.attr.out_dir, ctx.attr.root_dir)
        if a.is_source or a_path != a_out:
            asset = ctx.actions.declare_file(a_out)
            copy_file_action(ctx, a, asset)
            assets_outs.append(asset)

    outputs = js_outs + map_outs + typings_outs + typing_maps_outs
    if ctx.outputs.buildinfo_out:
        common_args.extend(["--tsBuildInfoFile", to_output_relative_path(ctx.outputs.buildinfo_out)])
        outputs.append(ctx.outputs.buildinfo_out)

    output_sources = js_outs + map_outs + assets_outs + ctx.files.pretranspiled_js

    # Add JS inputs that collide with outputs (see #250).
    #
    # Unfortunately this duplicates logic in ts_lib._to_js_out_paths:
    # files collide iff the following conditions are met:
    # - They are JS files (ext in [js, json])
    # - out_dir == root_dir
    #
    # The duplication is hard to avoid, since out_paths works on path strings
    # (so it also works in the macro), but we need Files here.
    if ctx.attr.out_dir == ctx.attr.root_dir:
        for s in srcs_inputs:
            if _lib.is_js_src(s.path, ctx.attr.allow_js, ctx.attr.resolve_json_module):
                output_sources.append(s)

    typings_srcs = [s for s in srcs_inputs if _lib.is_typings_src(s.path)]

    # Make sure the user has acknowledged that transpiling is slow
    if len(outputs) > 0 and ctx.attr.transpile == -1 and not ctx.attr.emit_declaration_only and not options.default_to_tsc_transpiler:
        fail(transpiler_selection_required)

    output_types = typings_outs + typing_maps_outs + typings_srcs + ctx.files.pretranspiled_dts

    # What tsc will be emitting
    use_tsc_for_js = len(js_outs) > 0
    use_tsc_for_dts = len(typings_outs) > 0

    # Use a separate non-emitting action for type-checking when:
    #  - a isolated typechecking action was explicitly requested
    #  or
    #  - not invoking tsc for output files at all
    use_isolated_typecheck = ctx.attr.isolated_typecheck or not (use_tsc_for_js or use_tsc_for_dts)

    # Special case where there are no source outputs so we add output_types to the default outputs.
    default_outputs = output_sources if len(output_sources) else output_types

    srcs_tsconfig_deps = ctx.attr.srcs + [ctx.attr.tsconfig] + ctx.attr.deps

    inputs = copy_files_to_bin_actions(ctx, inputs)

    transitive_inputs.append(_gather_types_from_js_infos(srcs_tsconfig_deps))
    transitive_inputs_depset = depset(
        inputs,
        transitive = transitive_inputs,
    )

    # tsc action for type-checking
    if use_isolated_typecheck:
        # The type-checking action still need to produce some output, so we output the stdout
        # to a .typecheck file that ends up in the typecheck output group.
        typecheck_output = ctx.actions.declare_file(ctx.attr.name + ".typecheck")
        typecheck_outs.append(typecheck_output)

        typecheck_arguments = ctx.actions.args()
        typecheck_arguments.add_all(common_args)

        typecheck_arguments.add("--noEmit")

        env = {
            "BAZEL_BINDIR": ctx.bin_dir.path,
        }

        # In non-worker mode, we create the marker file by capturing stdout of the action
        # via the JS_BINARY__STDOUT_OUTPUT_FILE environment variable, but in worker mode, the
        # persistent worker protocol communicates with the worker process via stdin/stdout, so
        # the output cannot just be captured. Instead, we tell the worker where to write the
        # marker file by passing the path via the --bazelValidationFile flag.
        if supports_workers:
            typecheck_arguments.use_param_file("@%s", use_always = True)
            typecheck_arguments.set_param_file_format("multiline")
            typecheck_arguments.add("--bazelValidationFile", typecheck_output.short_path)
        else:
            env["JS_BINARY__STDOUT_OUTPUT_FILE"] = typecheck_output.path

        ctx.actions.run(
            executable = executable,
            inputs = transitive_inputs_depset,
            arguments = [typecheck_arguments],
            outputs = [typecheck_output],
            mnemonic = "TsProjectCheck",
            execution_requirements = execution_requirements,
            resource_set = resource_set(ctx.attr),
            progress_message = "Type-checking TypeScript project %s [tsc -p %s]" % (
                ctx.label,
                tsconfig_path,
            ),
            env = env,
        )
    else:
        typecheck_outs.extend(output_types)

    if use_tsc_for_js or use_tsc_for_dts:
        tsc_emit_arguments = ctx.actions.args()
        tsc_emit_arguments.add_all(common_args)

        # Type-checking is done async as a separate action and can be skipped.
        if ctx.attr.isolated_typecheck:
            tsc_emit_arguments.add("--noCheck")
            tsc_emit_arguments.add("--skipLibCheck")
            tsc_emit_arguments.add("--noResolve")

        if not use_tsc_for_js:
            # Not emitting js
            tsc_emit_arguments.add("--emitDeclarationOnly")

        elif not use_tsc_for_dts:
            # Not emitting declarations
            tsc_emit_arguments.add("--declaration", "false")

        verb = "Transpiling" if ctx.attr.isolated_typecheck else "Transpiling & type-checking"

        inputs_depset = inputs if ctx.attr.isolated_typecheck else transitive_inputs_depset

        if supports_workers:
            tsc_emit_arguments.use_param_file("@%s", use_always = True)
            tsc_emit_arguments.set_param_file_format("multiline")

        ctx.actions.run(
            executable = executable,
            inputs = inputs_depset,
            arguments = [tsc_emit_arguments],
            outputs = outputs,
            mnemonic = "TsProjectEmit" if ctx.attr.isolated_typecheck else "TsProject",
            execution_requirements = execution_requirements,
            resource_set = resource_set(ctx.attr),
            progress_message = "%s TypeScript project %s [tsc -p %s]" % (
                verb,
                ctx.label,
                tsconfig_path,
            ),
            env = {
                "BAZEL_BINDIR": ctx.bin_dir.path,
            },
        )

    transitive_sources = js_lib_helpers.gather_transitive_sources(output_sources, srcs_tsconfig_deps)

    transitive_types = js_lib_helpers.gather_transitive_types(output_types, srcs_tsconfig_deps)

    npm_sources = js_lib_helpers.gather_npm_sources(
        srcs = ctx.attr.srcs + [ctx.attr.tsconfig],
        deps = ctx.attr.deps,
    )

    npm_package_store_infos = js_lib_helpers.gather_npm_package_store_infos(
        targets = ctx.attr.srcs + ctx.attr.data + ctx.attr.deps,
    )

    output_types_depset = depset(output_types)
    output_sources_depset = depset(output_sources)

    # Align runfiles config with rules_js js_library() to align behaviour.
    # See https://github.com/aspect-build/rules_js/blob/v2.1.0/js/private/js_library.bzl#L241-L254
    runfiles = js_lib_helpers.gather_runfiles(
        ctx = ctx,
        sources = output_sources_depset,
        data = ctx.attr.data,
        deps = srcs_tsconfig_deps,
        data_files = ctx.files.data,
        copy_data_files_to_bin = True,  # NOTE: configurable (default true) in js_library()
        no_copy_to_bin = [],  # NOTE: configurable (default []) in js_library()
        include_sources = True,
        include_types = False,
        include_transitive_sources = True,
        include_transitive_types = False,
        include_npm_sources = True,
    )

    providers = [
        DefaultInfo(
            files = depset(default_outputs),
            runfiles = runfiles,
        ),
        js_info(
            target = ctx.label,
            sources = output_sources_depset,
            types = output_types_depset,
            transitive_sources = transitive_sources,
            transitive_types = transitive_types,
            npm_sources = npm_sources,
            npm_package_store_infos = npm_package_store_infos,
        ),
        TsConfigInfo(deps = depset(tsconfig_inputs, transitive = tsconfig_transitive_deps)),
        OutputGroupInfo(
            types = output_types_depset,
            typecheck = depset(typecheck_outs),
            # make the inputs to the tsc action available for analysis testing
            _action_inputs = transitive_inputs_depset,
            # https://bazel.build/extending/rules#validations_output_group
            # "hold the otherwise unused outputs of validation actions"
            _validation = validation_outs,
        ),
        coverage_common.instrumented_files_info(
            ctx,
            source_attributes = ["srcs"],
            dependency_attributes = ["deps"],
            extensions = ["ts", "tsx"],
        ),
    ]

    return providers

lib = struct(
    implementation = _ts_project_impl,
    attrs = dicts.add(COMPILER_OPTION_ATTRS, STD_ATTRS, OUTPUT_ATTRS, resource_set_attr),
)

ts_project = rule(
    doc = """Implementation rule behind the ts_project macro.
    Most users should use [ts_project](#ts_project) instead.

    This skips conveniences like validation of the tsconfig attributes, default settings
    for srcs and tsconfig, and pre-declaring output files.
    """,
    implementation = lib.implementation,
    attrs = lib.attrs,
    toolchains = COPY_FILE_TO_BIN_TOOLCHAINS,
)
