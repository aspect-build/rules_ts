"""Define module extensions for using rules_ts with bzlmod.
See https://bazel.build/docs/bzlmod#extension-definition
"""

load("//ts/private:npm_repositories.bzl", "npm_dependencies", "parse_typescript_version")
load("//ts/private:versions.bzl", "NATIVE_TYPESCRIPT_VERSIONS", "TOOL_VERSIONS")

LATEST_TYPESCRIPT_VERSION = TOOL_VERSIONS.keys()[-1]
_DEFAULT_VALIDATOR_TYPESCRIPT_VERSION = "6.0.3"

def _extension_impl(module_ctx):
    # Prefer the root module's tag when multiple modules request the same repo.
    selected = {}
    for mod in module_ctx.modules:
        is_root = mod.is_root
        for attr in mod.tags.deps:
            existing = selected.get(attr.name)
            if existing and not is_root:
                # Validate that non-root modules don't specify conflicting versions
                if not existing["is_root"]:
                    existing_attr = existing["attr"]
                    if attr.ts_version != existing_attr.ts_version or \
                       attr.ts_version_from != existing_attr.ts_version_from or \
                       attr.ts_integrity != existing_attr.ts_integrity or \
                       attr.validator_ts_version != existing_attr.validator_ts_version or \
                       attr.validator_ts_integrity != existing_attr.validator_ts_integrity:
                        fail("""Multiple non-root modules specify different versions for '{name}'.
    Module '{existing_mod}' requests: ts_version={existing_version}, ts_version_from={existing_from}, ts_integrity={existing_integrity}, validator_ts_version={existing_validator_version}, validator_ts_integrity={existing_validator_integrity}
    Module '{current_mod}' requests: ts_version={current_version}, ts_version_from={current_from}, ts_integrity={current_integrity}, validator_ts_version={current_validator_version}, validator_ts_integrity={current_validator_integrity}
To resolve this conflict, the root module should explicitly specify the desired version.""".format(
                            name = attr.name,
                            existing_mod = existing["module_name"],
                            existing_version = existing_attr.ts_version or "(not set)",
                            existing_from = existing_attr.ts_version_from or "(not set)",
                            existing_integrity = existing_attr.ts_integrity or "(not set)",
                            existing_validator_integrity = existing_attr.validator_ts_integrity or "(not set)",
                            existing_validator_version = existing_attr.validator_ts_version or "(not set)",
                            current_mod = mod.name,
                            current_version = attr.ts_version or "(not set)",
                            current_from = attr.ts_version_from or "(not set)",
                            current_integrity = attr.ts_integrity or "(not set)",
                            current_validator_integrity = attr.validator_ts_integrity or "(not set)",
                            current_validator_version = attr.validator_ts_version or "(not set)",
                        ))
                continue
            selected[attr.name] = {
                "attr": attr,
                "is_root": is_root,
                "module_name": mod.name,
            }

    for entry in selected.values():
        attr = entry["attr"]
        if attr.ts_version_from and hasattr(module_ctx, "watch"):
            module_ctx.watch(attr.ts_version_from)

        ts_version = attr.ts_version
        if not ts_version and not attr.ts_version_from:
            ts_version = LATEST_TYPESCRIPT_VERSION
        resolved_ts_version = ts_version
        if attr.ts_version_from:
            resolved_ts_version, _ = parse_typescript_version(module_ctx.read(attr.ts_version_from), attr.ts_version_from)

        validator_repository = None
        if resolved_ts_version in NATIVE_TYPESCRIPT_VERSIONS:
            validator_ts_version = attr.validator_ts_version or _DEFAULT_VALIDATOR_TYPESCRIPT_VERSION
            if not validator_ts_version.startswith("6."):
                fail("validator_ts_version must select a TypeScript 6 release, got {}".format(validator_ts_version))

            validator_repository = "{}_validator".format(attr.name)
            if validator_repository in selected:
                fail("validator repository '{}' conflicts with an explicitly requested TypeScript repository".format(validator_repository))

            npm_dependencies(
                name = validator_repository,
                ts_version = validator_ts_version,
                ts_integrity = attr.validator_ts_integrity,
            )

        npm_dependencies(
            name = attr.name,
            ts_version = ts_version,
            ts_version_from = attr.ts_version_from,
            ts_integrity = attr.ts_integrity,
            validator_repository = validator_repository,
        )

ext = module_extension(
    implementation = _extension_impl,
    tag_classes = {
        "deps": tag_class(attrs = {
            "name": attr.string(default = "npm_typescript"),
            "ts_version": attr.string(),
            "ts_version_from": attr.label(),
            "ts_integrity": attr.string(),
            "validator_ts_integrity": attr.string(
                doc = "Integrity of the classic TypeScript package used only to validate native TypeScript. Defaults to the mirrored integrity.",
            ),
            "validator_ts_version": attr.string(
                doc = "Classic TypeScript version used only to validate native TypeScript. Defaults to 6.0.3.",
            ),
        }),
    },
)
