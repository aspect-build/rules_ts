"""TypeScript action inputs without declaration maps."""

load("@aspect_rules_js//js:providers.bzl", "JsInfo")

# JsInfo must retain declaration maps for downstream consumers. Cache the
# compiler-only view so ts_project does not flatten the same transitive depsets
# again at every level of a TypeScript dependency graph.
CompilerInputsInfo = provider(fields = ["types", "npm_sources", "tsconfig_deps"])

def without_declaration_maps(files):
    # External JsInfo depsets have no compiler-only view, so filter them when
    # they enter our provider graph.
    return depset([
        file
        for file in files.to_list()
        if not file.basename.endswith((".d.ts.map", ".d.mts.map", ".d.cts.map"))
    ])

def gather_types(targets):
    return depset(transitive = [
        target[CompilerInputsInfo].types if CompilerInputsInfo in target else without_declaration_maps(target[JsInfo].transitive_types)
        for target in targets
        if JsInfo in target
    ])

def gather_npm_sources(targets):
    return depset(transitive = [
        target[CompilerInputsInfo].npm_sources if CompilerInputsInfo in target else without_declaration_maps(target[JsInfo].npm_sources)
        for target in targets
        if JsInfo in target
    ])
