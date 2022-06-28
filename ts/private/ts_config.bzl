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

load("@aspect_bazel_lib//lib:paths.bzl", "relative_file")
load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "copy_file_to_bin_action", "copy_files_to_bin_actions")
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
    transitive_deps = []
    for dep in ctx.attr.deps:
        if TsConfigInfo in dep:
            transitive_deps.extend(dep[TsConfigInfo].deps)
    return [
        DefaultInfo(files = depset(files)),
        TsConfigInfo(deps = files + copy_files_to_bin_actions(ctx, ctx.files.deps) + transitive_deps),
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
)

def _filter_input_files(files, allow_js, resolve_json_module):
    return [
        f
        for f in files
        if _lib.is_ts_src(f.basename, allow_js) or _lib.is_json_src(f.basename, resolve_json_module)
    ]

def _write_tsconfig_rule(ctx):
    # TODO: is it useful to expand Make variables in the content?
    content = "\n".join(ctx.attr.content)
    if ctx.attr.extends:
        content = content.replace(
            "__extends__",
            relative_file(ctx.file.extends.short_path, ctx.outputs.out.short_path),
        )

    filtered_files = _filter_input_files(ctx.files.files, ctx.attr.allow_js, ctx.attr.resolve_json_module)
    if filtered_files:
        content = content.replace(
            "\"__files__\"",
            str([relative_file(f.short_path, ctx.outputs.out.short_path) for f in filtered_files]),
        )
    ctx.actions.write(
        output = ctx.outputs.out,
        content = content,
    )
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

write_tsconfig_rule = rule(
    implementation = _write_tsconfig_rule,
    attrs = {
        "content": attr.string_list(),
        "extends": attr.label(allow_single_file = True),
        "files": attr.label_list(allow_files = True),
        "out": attr.output(),
        "allow_js": attr.bool(),
        "resolve_json_module": attr.bool(),
    },
)

# Syntax sugar around skylib's write_file
def write_tsconfig(name, config, files, out, extends = None, allow_js = None, resolve_json_module = None):
    """Wrapper around bazel_skylib's write_file which understands tsconfig paths

    Args:
        name: name of the resulting write_file rule
        config: tsconfig dictionary
        files: list of input .ts files to put in the files[] array
        out: the file to write
        extends: a label for a tsconfig.json file to extend from, if any
        allow_js: value of the allowJs tsconfig property
        resolve_json_module: value of the resolveJsonModule tsconfig property
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
        content = [json.encode(amended_config)],
        out = out,
        allow_js = allow_js,
        resolve_json_module = resolve_json_module,
    )
