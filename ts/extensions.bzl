"""Define module extensions for using rules_ts with bzlmod.
See https://bazel.build/docs/bzlmod#extension-definition
"""

load("//ts:repositories.bzl", "LATEST_TYPESCRIPT_VERSION")
load("//ts/private:npm_repositories.bzl", "npm_dependencies")

_DEPRECATED_ATTR_MSG = """\
WARNING: rules_ts: the 'ts_version', 'ts_version_from' and 'ts_integrity' attributes of the
TypeScript module extension are deprecated and will be removed in the next major release. Rename
them to 'version', 'version_from' and 'integrity':

    typescript = use_extension("@aspect_rules_ts//ts:extensions.bzl", "typescript")
    typescript.deps(version = "...")   # or version_from = "//:package.json"
    use_repo(typescript, "npm_typescript")
"""

_DEPRECATED_SYMBOL_MSG = """\
WARNING: rules_ts: the 'ext' module extension symbol is deprecated and will be removed in the next
major release. Rename `use_extension(..., "ext")` to `use_extension(..., "typescript")`.
"""

def _normalize(attr):
    """Read a `deps` tag, preferring the new attrs over the deprecated `ts_*` aliases.

    Returns (version, version_from, integrity, used_deprecated_attr).
    """
    used_new = bool(attr.version or attr.version_from or attr.integrity)
    used_deprecated = bool(attr.ts_version or attr.ts_version_from or attr.ts_integrity)
    if used_new and used_deprecated:
        fail("The typescript.deps tag for '{}' mixes the current 'version'/'version_from'/'integrity' attributes with the deprecated 'ts_*' aliases; use only one set.".format(attr.name))
    return (
        attr.version or attr.ts_version,
        attr.version_from or attr.ts_version_from,
        attr.integrity or attr.ts_integrity,
        used_deprecated,
    )

def _extension_impl(module_ctx, deprecated_symbol):
    # Prefer the root module's tag when multiple modules request the same repo.
    selected = {}
    root_direct_deps = {}
    root_direct_dev_deps = {}
    root_used_deprecated_attr = False
    for mod in module_ctx.modules:
        is_root = hasattr(mod, "is_root") and mod.is_root
        for attr in mod.tags.deps:
            version, version_from, integrity, used_deprecated = _normalize(attr)
            if is_root:
                if used_deprecated:
                    root_used_deprecated_attr = True
                if module_ctx.is_dev_dependency(attr):
                    root_direct_dev_deps[attr.name] = None
                else:
                    root_direct_deps[attr.name] = None
            existing = selected.get(attr.name)
            if existing and not is_root:
                # Validate that non-root modules don't specify conflicting versions
                if not existing["is_root"]:
                    if version != existing["version"] or \
                       version_from != existing["version_from"] or \
                       integrity != existing["integrity"]:
                        fail("""Multiple non-root modules specify different versions for '{name}'.
    Module '{existing_mod}' requests: version={existing_version}, version_from={existing_from}, integrity={existing_integrity}
    Module '{current_mod}' requests: version={current_version}, version_from={current_from}, integrity={current_integrity}
To resolve this conflict, the root module should explicitly specify the desired version.""".format(
                            name = attr.name,
                            existing_mod = existing["module_name"],
                            existing_version = existing["version"] or "(not set)",
                            existing_from = existing["version_from"] or "(not set)",
                            existing_integrity = existing["integrity"] or "(not set)",
                            current_mod = mod.name,
                            current_version = version or "(not set)",
                            current_from = version_from or "(not set)",
                            current_integrity = integrity or "(not set)",
                        ))
                continue
            selected[attr.name] = {
                "version": version,
                "version_from": version_from,
                "integrity": integrity,
                "is_root": is_root,
                "module_name": mod.name,
            }

    for name, entry in selected.items():
        version_from = entry["version_from"]
        if version_from and hasattr(module_ctx, "watch"):
            module_ctx.watch(version_from)

        ts_version = entry["version"]
        if not ts_version and not version_from:
            ts_version = LATEST_TYPESCRIPT_VERSION
        npm_dependencies(
            name = name,
            ts_version = ts_version,
            ts_version_from = version_from,
            ts_integrity = entry["integrity"],
        )

    # Emit deprecation warnings only for the root module (the only usages the user can act on).
    if deprecated_symbol:
        print(_DEPRECATED_SYMBOL_MSG)  # buildifier: disable=print
    if root_used_deprecated_attr:
        print(_DEPRECATED_ATTR_MSG)  # buildifier: disable=print

    # Bazel <6.2 lacks module_ctx.extension_metadata
    if not hasattr(module_ctx, "extension_metadata"):
        return None

    # A repo requested by both dev and non-dev usages of the root module is a non-dev dep.
    for name in root_direct_deps.keys():
        root_direct_dev_deps.pop(name, None)

    metadata_kwargs = {}
    if hasattr(module_ctx, "watch"):
        # Bazel 7.1+, the same release that added `reproducible`
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = root_direct_deps.keys(),
        root_module_direct_dev_deps = root_direct_dev_deps.keys(),
        **metadata_kwargs
    )

def _typescript_impl(module_ctx):
    return _extension_impl(module_ctx, deprecated_symbol = False)

def _ext_impl(module_ctx):
    return _extension_impl(module_ctx, deprecated_symbol = True)

_TAG_CLASSES = {
    "deps": tag_class(attrs = {
        "name": attr.string(default = "npm_typescript"),
        "version": attr.string(),
        "version_from": attr.label(),
        "integrity": attr.string(),
        # Deprecated: use version/version_from/integrity instead. Retained for backward compatibility.
        "ts_version": attr.string(),
        "ts_version_from": attr.label(),
        "ts_integrity": attr.string(),
    }),
}

typescript = module_extension(
    implementation = _typescript_impl,
    tag_classes = _TAG_CLASSES,
)

# Deprecated: use `typescript` instead. Retained for backward compatibility.
ext = module_extension(
    implementation = _ext_impl,
    tag_classes = _TAG_CLASSES,
)
