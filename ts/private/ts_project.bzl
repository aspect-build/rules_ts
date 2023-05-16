"ts_project rule"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_file_to_bin_action", "copy_files_to_bin_actions")
load("@aspect_bazel_lib//lib:paths.bzl", "to_output_relative_path")
load("@aspect_bazel_lib//lib:platform_utils.bzl", "platform_utils")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@aspect_rules_js//js:providers.bzl", "JsInfo", "js_info")
load("@aspect_rules_js//js:libs.bzl", "js_lib_helpers")
load("@aspect_rules_js//npm:providers.bzl", "NpmPackageStoreInfo")
load(":ts_lib.bzl", "COMPILER_OPTION_ATTRS", "OUTPUT_ATTRS", "STD_ATTRS", "ValidOptionsInfo", _lib = "lib")
load(":ts_config.bzl", "TsConfigInfo")
load(":ts_validate_options.bzl", _validate_lib = "lib")
load(":options.bzl", "OptionsInfo")

# Forked from js_lib_helpers.js_lib_helpers.gather_files_from_js_providers to not
# include any sources; only transitive declarations & npm linked packages
def _gather_declarations_from_js_providers(targets):
    files_depsets = []
    files_depsets.extend([
        target[JsInfo].transitive_declarations
        for target in targets
        if JsInfo in target and hasattr(target[JsInfo], "transitive_declarations")
    ])
    files_depsets.extend([
        target[JsInfo].transitive_npm_linked_package_files
        for target in targets
        if JsInfo in target and hasattr(target[JsInfo], "transitive_npm_linked_package_files")
    ])
    files_depsets.extend([
        target[NpmPackageStoreInfo].transitive_files
        for target in targets
        if NpmPackageStoreInfo in target and hasattr(target[NpmPackageStoreInfo], "transitive_files")
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

    srcs = [_lib.relative_to_package(src.path, ctx) for src in srcs_inputs]

    # Recalculate outputs inside the rule implementation.
    # The outs are first calculated in the macro in order to try to predetermine outputs so they can be declared as
    # outputs on the rule. This provides the benefit of being able to reference an output file with a label.
    # However, it is not possible to evaluate files in outputs of other rules such as filegroup, therefore the outs are
    # recalculated here.
    typings_out_dir = ctx.attr.declaration_dir or ctx.attr.out_dir
    js_outs = _lib.declare_outputs(ctx, [] if not ctx.attr.transpile else _lib.calculate_js_outs(srcs, ctx.attr.out_dir, ctx.attr.root_dir, ctx.attr.allow_js, ctx.attr.resolve_json_module, ctx.attr.preserve_jsx, ctx.attr.emit_declaration_only))
    map_outs = _lib.declare_outputs(ctx, [] if not ctx.attr.transpile else _lib.calculate_map_outs(srcs, ctx.attr.out_dir, ctx.attr.root_dir, ctx.attr.source_map, ctx.attr.preserve_jsx, ctx.attr.emit_declaration_only))
    typings_outs = _lib.declare_outputs(ctx, _lib.calculate_typings_outs(srcs, typings_out_dir, ctx.attr.root_dir, ctx.attr.declaration, ctx.attr.composite, ctx.attr.allow_js))
    typing_maps_outs = _lib.declare_outputs(ctx, _lib.calculate_typing_maps_outs(srcs, typings_out_dir, ctx.attr.root_dir, ctx.attr.declaration_map, ctx.attr.allow_js))

    arguments = ctx.actions.args()
    execution_requirements = {}
    executable = ctx.executable.tsc

    supports_workers = ctx.attr.supports_workers

    # workers can be enabled/disabled globally. if no supports_workers attribute is set explicitly for this target,
    # which is indicated by internal_do_not_depend_supports_workers_is_none attribute, then set it to global supports_workers config
    # TODO(2.0): remove this
    if ctx.attr.internal_do_not_depend_supports_workers_is_none:
        supports_workers = options.supports_workers

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
        # Set to use a multiline param-file for worker mode
        arguments.use_param_file("@%s", use_always = True)
        arguments.set_param_file_format("multiline")
        execution_requirements["supports-workers"] = "1"
        execution_requirements["worker-key-mnemonic"] = "TsProject"
        executable = ctx.executable.tsc_worker

    # Add all arguments from options first to allow users override them via args.
    arguments.add_all(options.args)

    # Add user specified arguments *before* rule supplied arguments
    arguments.add_all(ctx.attr.args)

    outdir = _lib.join(
        ctx.label.workspace_root,
        _lib.join(ctx.label.package, ctx.attr.out_dir) if ctx.attr.out_dir else ctx.label.package,
    )
    tsconfig_path = to_output_relative_path(tsconfig)
    arguments.add_all([
        "--project",
        tsconfig_path,
        "--outDir",
        outdir,
        "--rootDir",
        _lib.calculate_root_dir(ctx),
    ])
    if len(typings_outs) > 0:
        declaration_dir = _lib.join(ctx.label.workspace_root, ctx.label.package, typings_out_dir)
        arguments.add_all([
            "--declarationDir",
            declaration_dir,
        ])

    inputs = srcs_inputs[:]
    transitive_inputs = []
    for dep in ctx.attr.deps:
        # When TypeScript builds a composite project, our compilation will want to read the tsconfig.json of
        # composite projects we reference.
        # Otherwise we'd get an error like
        # examples/project_references/lib_b/tsconfig.json(5,9): error TS6053:
        # File 'execroot/aspect_rules_ts/bazel-out/k8-fastbuild/bin/examples/project_references/lib_a/tsconfig.json' not found.
        if ctx.attr.composite and TsConfigInfo in dep:
            transitive_inputs.append(dep[TsConfigInfo].deps)
        if ValidOptionsInfo in dep:
            inputs.append(dep[ValidOptionsInfo].marker)

    # Gather TsConfig info from both the direct (tsconfig) and indirect (extends) attribute
    tsconfig_inputs = copy_files_to_bin_actions(ctx, _validate_lib.tsconfig_inputs(ctx).to_list())
    inputs.extend(tsconfig_inputs)

    outputs = js_outs + map_outs + typings_outs + typing_maps_outs
    if ctx.outputs.buildinfo_out:
        arguments.add_all([
            "--tsBuildInfoFile",
            to_output_relative_path(ctx.outputs.buildinfo_out),
        ])
        outputs.append(ctx.outputs.buildinfo_out)
    output_sources = js_outs + map_outs + copy_files_to_bin_actions(ctx, ctx.files.assets)
    typings_srcs = [s for s in srcs_inputs if _lib.is_typings_src(s.path)]

    if len(js_outs) + len(typings_outs) < 1:
        label = "//{}:{}".format(ctx.label.package, ctx.label.name)
        if len(typings_srcs) > 0:
            no_outs_msg = """ts_project target {target} only has typings in srcs.
Since there is no `tsc` action to perform, there are no generated outputs.

> ts_project doesn't support "typecheck-only"; see https://github.com/aspect-build/rules_ts/issues/88

This should be changed to js_library, which can be done by running:

    buildozer 'new_load @aspect_rules_js//js:defs.bzl js_library' //{pkg}:__pkg__
    buildozer 'set kind js_library' {target}
    buildozer 'remove declaration' {target}

""".format(
                target = label,
                pkg = ctx.label.package,
            )
        elif ctx.attr.transpile:
            no_outs_msg = """ts_project target %s is configured to produce no outputs.

This might be because
- you configured it with `noEmit`
- the `srcs` are empty
- `srcs` has elements producing non-ts outputs
""" % label
        else:
            no_outs_msg = "ts_project target %s with custom transpiler needs 'declaration = True'." % label
        fail(no_outs_msg + """
This is an error because Bazel does not run actions unless their outputs are needed for the requested targets to build.
""")

    output_declarations = typings_outs + typing_maps_outs + typings_srcs

    # Default outputs (DefaultInfo files) is what you see on the command-line for a built
    # library, and determines what files are used by a simple non-provider-aware downstream
    # library. Only the JavaScript outputs are intended for use in non-TS-aware dependents.
    if ctx.attr.transpile:
        # Special case case where there are no source outputs and we don't have a custom
        # transpiler so we add output_declarations to the default outputs
        default_outputs = output_sources[:] if len(output_sources) else output_declarations[:]
    else:
        # We must avoid tsc writing any JS files in this case, as tsc was only run for typings, and some other
        # action will try to write the JS files. We must avoid collisions where two actions write the same file.
        arguments.add("--emitDeclarationOnly")

        # We don't produce any DefaultInfo outputs in this case, because we avoid running the tsc action
        # unless the output_declarations are requested.
        default_outputs = []

    inputs_depset = depset()
    if len(outputs) > 0:
        inputs_depset = depset(
            copy_files_to_bin_actions(ctx, inputs),
            transitive = transitive_inputs + [_gather_declarations_from_js_providers(ctx.attr.srcs + [ctx.attr.tsconfig] + ctx.attr.deps)],
        )

        verb = "Transpiling & type-checking"
        if not ctx.attr.transpile:
            verb = "Type-checking"
        elif not ctx.attr.declaration:
            verb = "Transpiling"

        ctx.actions.run(
            executable = executable,
            inputs = inputs_depset,
            arguments = [arguments],
            outputs = outputs,
            mnemonic = "TsProject",
            execution_requirements = execution_requirements,
            progress_message = "%s TypeScript project %s [tsc -p %s]" % (
                verb,
                ctx.label,
                tsconfig_path,
            ),
            env = {
                "BAZEL_BINDIR": ctx.bin_dir.path,
            },
        )

    transitive_sources = js_lib_helpers.gather_transitive_sources(output_sources, ctx.attr.srcs + [ctx.attr.tsconfig] + ctx.attr.deps)

    transitive_declarations = js_lib_helpers.gather_transitive_declarations(output_declarations, ctx.attr.srcs + [ctx.attr.tsconfig] + ctx.attr.deps)

    npm_linked_packages = js_lib_helpers.gather_npm_linked_packages(
        srcs = ctx.attr.srcs + [ctx.attr.tsconfig],
        deps = ctx.attr.deps,
    )

    npm_package_store_deps = js_lib_helpers.gather_npm_package_store_deps(
        targets = ctx.attr.data + ctx.attr.deps,
    )

    output_declarations_depset = depset(output_declarations)
    output_sources_depset = depset(output_sources)

    runfiles = js_lib_helpers.gather_runfiles(
        ctx = ctx,
        sources = output_sources_depset,
        data = ctx.attr.data,
        deps = ctx.attr.srcs + [ctx.attr.tsconfig] + ctx.attr.deps,
    )

    providers = [
        DefaultInfo(
            files = depset(default_outputs),
            runfiles = runfiles,
        ),
        js_info(
            declarations = output_declarations_depset,
            npm_linked_package_files = npm_linked_packages.direct_files,
            npm_linked_packages = npm_linked_packages.direct,
            npm_package_store_deps = npm_package_store_deps,
            sources = output_sources_depset,
            transitive_declarations = transitive_declarations,
            transitive_npm_linked_package_files = npm_linked_packages.transitive_files,
            transitive_npm_linked_packages = npm_linked_packages.transitive,
            transitive_sources = transitive_sources,
        ),
        TsConfigInfo(deps = depset(tsconfig_inputs, transitive = [
            dep[TsConfigInfo].deps
            for dep in ctx.attr.deps
            if TsConfigInfo in dep
        ])),
        OutputGroupInfo(
            types = output_declarations_depset,
            # make the inputs to the tsc action available for analysis testing
            _action_inputs = inputs_depset,
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
    attrs = dicts.add(COMPILER_OPTION_ATTRS, STD_ATTRS, OUTPUT_ATTRS),
)

ts_project = rule(
    doc = """Implementation rule behind the ts_project macro.
    Most users should use [ts_project](#ts_project) instead.

    This skips conveniences like validation of the tsconfig attributes, default settings
    for srcs and tsconfig, and pre-declaring output files.
    """,
    implementation = lib.implementation,
    attrs = lib.attrs,
)
