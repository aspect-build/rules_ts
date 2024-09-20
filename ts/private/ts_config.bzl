# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"tsconfig.json files using extends"

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "COPY_FILE_TO_BIN_TOOLCHAINS", "copy_file_to_bin_action", "copy_files_to_bin_actions")
load("@aspect_bazel_lib//lib:paths.bzl", "relative_file")
load("@aspect_rules_js//js:libs.bzl", "js_lib_helpers")
load("@aspect_rules_js//js:providers.bzl", "js_info")
load(":ts_lib.bzl", _lib = "lib")

TsConfigInfo = provider(
    doc = """Provides TypeScript configuration, in the form of a tsconfig.json file
        along with any transitively referenced tsconfig.json files chained by the
        "extends" feature""",
    fields = {
        "deps": "all tsconfig.json files needed to configure TypeScript",
    },
)

def _ts_config_impl(ctx):
    files = [copy_file_to_bin_action(ctx, ctx.file.src)]

    transitive_deps = [
        depset(copy_files_to_bin_actions(ctx, ctx.files.deps)),
        js_lib_helpers.gather_files_from_js_infos(
            targets = ctx.attr.deps,
            include_sources = True,
            include_types = True,
            include_transitive_sources = True,
            include_transitive_types = True,
            include_npm_sources = True,
        ),
    ]

    # TODO: now that ts_config.bzl provides a JsInfo, we should be able to remove TsConfigInfo in the future
    # since transitive files will now be passed through transitive_types in JsInfo
    for dep in ctx.attr.deps:
        if TsConfigInfo in dep:
            transitive_deps.append(dep[TsConfigInfo].deps)

    transitive_sources = js_lib_helpers.gather_transitive_sources([], ctx.attr.deps)

    transitive_types = js_lib_helpers.gather_transitive_types(files, ctx.attr.deps)

    npm_sources = js_lib_helpers.gather_npm_sources(
        srcs = [],
        deps = ctx.attr.deps,
    )

    npm_package_store_infos = js_lib_helpers.gather_npm_package_store_infos(
        targets = ctx.attr.deps,
    )

    files_depset = depset(files)

    runfiles = js_lib_helpers.gather_runfiles(
        ctx = ctx,
        sources = depset(),  # tsconfig.json file won't be needed at runtime
        data = [],
        deps = ctx.attr.deps,
    )

    return [
        DefaultInfo(
            files = files_depset,
            runfiles = runfiles,
        ),
        js_info(
            # provide tsconfig.json file via `types` and not `sources` since they are only needed
            # for downstream ts_project rules and not in downstream runtime binary rules
            target = ctx.label,
            sources = depset(),
            types = files_depset,
            transitive_sources = transitive_sources,
            transitive_types = transitive_types,
            npm_sources = npm_sources,
            npm_package_store_infos = npm_package_store_infos,
        ),
        TsConfigInfo(deps = depset(files, transitive = transitive_deps)),
    ]

ts_config = rule(
    implementation = _ts_config_impl,
    attrs = {
        "deps": attr.label_list(
            doc = """Additional tsconfig.json files referenced via extends""",
            allow_files = True,
        ),
        "src": attr.label(
            doc = """The tsconfig.json file passed to the TypeScript compiler""",
            allow_single_file = True,
            mandatory = True,
        ),
    },
    doc = """Allows a tsconfig.json file to extend another file.

Normally, you just give a single `tsconfig.json` file as the tsconfig attribute
of a `ts_library` or `ts_project` rule. However, if your `tsconfig.json` uses the `extends`
feature from TypeScript, then the Bazel implementation needs to know about that
extended configuration file as well, to pass them both to the TypeScript compiler.
""",
    toolchains = COPY_FILE_TO_BIN_TOOLCHAINS,
)

def _filter_input_files(files, allow_js, resolve_json_module):
    return [
        f
        for f in files
        # include typescript, json & declaration sources
        if _lib.is_ts_src(f.basename, allow_js, resolve_json_module) or _lib.is_typings_src(f.basename)
    ]

def _write_tsconfig_rule(ctx):
    # TODO: is it useful to expand Make variables in the content?
    content = ctx.attr.content
    if ctx.attr.extends:
        # Unlike other paths in the tsconfig file, the "extends" property
        # is documented: "The path may use Node.js style resolution."
        # https://www.typescriptlang.org/tsconfig#extends
        # That means that we must start with explicit "./" segment.
        extends_path = relative_file(ctx.file.extends.short_path, ctx.outputs.out.short_path)
        if not extends_path.startswith("../"):
            extends_path = "./" + extends_path
        content = content.replace("__extends__", extends_path)

    filtered_files = _filter_input_files(ctx.files.files, ctx.attr.allow_js, ctx.attr.resolve_json_module)

    # Update file paths to be relative to the tsconfig file, including a ./ prefix
    # to ensure paths are all relative to the config file.
    package_prefix = ctx.label.package + "/"
    filtered_files = [
        "./" + f.short_path.removeprefix(package_prefix)
        for f in filtered_files
    ]

    content = content.replace("\"__files__\"", str(filtered_files))
    ctx.actions.write(
        output = ctx.outputs.out,
        content = content,
    )
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

write_tsconfig_rule = rule(
    implementation = _write_tsconfig_rule,
    attrs = {
        "content": attr.string(),
        "extends": attr.label(allow_single_file = True),
        "files": attr.label_list(allow_files = True),
        "out": attr.output(),
        "allow_js": attr.bool(),
        "resolve_json_module": attr.bool(),
    },
)

# Syntax sugar around skylib's write_file
def write_tsconfig(name, config, files, out, extends = None, allow_js = None, resolve_json_module = None, **kwargs):
    """Wrapper around bazel_skylib's write_file which understands tsconfig paths

    Args:
        name: name of the resulting write_file rule
        config: tsconfig dictionary
        files: list of input .ts files to put in the files[] array
        out: the file to write
        extends: a label for a tsconfig.json file to extend from, if any
        allow_js: value of the allowJs tsconfig property
        resolve_json_module: value of the resolveJsonModule tsconfig property
        **kwargs: Other common named parameters such as `tags` or `visibility`
    """
    if out.find("/") >= 0:
        fail("tsconfig should be generated in the package directory, to make relative pathing simple")

    if extends:
        config["extends"] = "__extends__"

    amended_config = struct(
        files = "__files__",
        **config
    )
    write_tsconfig_rule(
        name = name,
        files = files,
        extends = extends,
        content = json.encode(amended_config),
        out = out,
        allow_js = allow_js,
        resolve_json_module = resolve_json_module,
        **kwargs
    )
