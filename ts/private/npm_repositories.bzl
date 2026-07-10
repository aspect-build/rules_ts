"""Runtime dependencies fetched from npm"""

load("@bazel_tools//tools/build_defs/repo:cache.bzl", "get_default_canonical_id")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//ts/private:versions.bzl", "NATIVE_TYPESCRIPT_VERSIONS", "TOOL_VERSIONS")

def read_ts_version(rctx, version, version_from):
    """Determine the typescript version for a repository rule.

    Args:
        rctx: repository_ctx
        version: an explicit version, or None
        version_from: label of a package.json or resolved.json declaring the version, or None

    Returns:
        struct with `version` and `integrity` fields; integrity is None unless
        version_from is a resolved.json carrying one.
    """
    integrity = None
    if not version:
        json_path = rctx.path(version_from)
        p = json.decode(rctx.read(json_path))

        # Allow use of "resolved.json", see https://github.com/aspect-build/rules_js/pull/1221
        if "$schema" in p.keys() and p["$schema"] == "https://docs.aspect.build/rules/aspect_rules_js/docs/npm_translate_lock":
            ts = p["version"]
            integrity = p["integrity"]
        elif "devDependencies" in p.keys() and "typescript" in p["devDependencies"]:
            ts = p["devDependencies"]["typescript"]
        elif "dependencies" in p.keys() and "typescript" in p["dependencies"]:
            ts = p["dependencies"]["typescript"]
        else:
            fail("key 'typescript' not found in either dependencies or devDependencies of %s" % json_path)
        version = ts

    # Note: we can't depend on bazel_skylib because this code is called from
    # the module extension so it's not "in scope" yet.
    # So we can't use versions.bzl to parse the version
    major_version = version.split(".")[0]
    if major_version.isdigit() and int(major_version) < 5:
        fail("typescript version {} is not supported, rules_ts requires typescript >= 5.0.0".format(version))

    return struct(version = version, integrity = integrity)

def _http_archive_version_impl(rctx):
    resolved = read_ts_version(rctx, rctx.attr.version, rctx.attr.version_from)
    version = resolved.version
    integrity = resolved.integrity

    native_typescript_version = NATIVE_TYPESCRIPT_VERSIONS.get(version, {})
    if integrity:
        pass
    elif rctx.attr.integrity:
        integrity = rctx.attr.integrity
    elif version in TOOL_VERSIONS.keys():
        integrity = TOOL_VERSIONS[version]
    elif native_typescript_version:
        integrity = native_typescript_version["integrity"]
    else:
        fail("""typescript version {} is not mirrored in rules_ts, is this a real version?
            If so, you must manually set 'ts_integrity'.
            If this is a semver range you must specify an exact version instead.
            See documentation on the rules_ts module extension.""".format(version))

    urls = [u.format(version) for u in rctx.attr.urls]

    rctx.download_and_extract(
        url = urls,
        integrity = integrity,
        # Prevents accidental re-use of cached versions that would otherwise
        # be used purely based on the "integrity" value. E.g. someone forgot
        # to update the integrity but the `ts_version` is already different.
        canonical_id = get_default_canonical_id(rctx, urls),
    )

    if not native_typescript_version and _has_native_packages(rctx):
        fail("""typescript version {} publishes pre-compiled compiler binaries that are not mirrored in rules_ts.
            See documentation on the rules_ts module extension.""".format(version))

    build_file_substitutions = {
        "ts_version": version,
        "# ts_tsc_toolchain": (_NATIVE_TSC_TOOLCHAIN_TARGET if native_typescript_version else _NODE_TSC_TOOLCHAIN_TARGET).format(
            repo_name = rctx.attr.repo_name,
        ),
    }
    rctx.template(
        "BUILD.bazel",
        rctx.path(rctx.attr._build_file),
        substitutions = build_file_substitutions,
        executable = False,
    )

    # Bazel <8.3.0 lacks rctx.repo_metadata
    if not hasattr(rctx, "repo_metadata"):
        return None

    return rctx.repo_metadata(reproducible = True)

def _has_native_packages(rctx):
    package_json = json.decode(rctx.read(rctx.path("package/package.json")))
    return any([dep.startswith("@typescript/") for dep in package_json.get("optionalDependencies", {}).keys()])

_NODE_TSC_TOOLCHAIN_TARGET = """# Toolchain exposing the NodeJS-hosted compiler. The rules_ts toolchains hub
# points at this for TypeScript versions that ship the compiler as JavaScript.
tsc_toolchain(
    name = "tsc_toolchain",
    tsc_binary = ":tsc",
    visibility = ["//visibility:public"],
)"""

_NATIVE_TSC_TOOLCHAIN_TARGET = """# The pre-compiled compiler binary for whichever platform the consuming
# configuration runs on, from the platform-specific repositories.
alias(
    name = "tsc_toolchain",
    actual = "@{repo_name}_toolchains//:tsc_toolchain",
    visibility = ["//visibility:public"],
)"""

http_archive_version = repository_rule(
    doc = "Re-implementation of http_archive that can read the version from package.json",
    implementation = _http_archive_version_impl,
    attrs = {
        "integrity": attr.string(doc = "Needed only if the ts version isn't mirrored in `versions.bzl`."),
        "repo_name": attr.string(
            doc = "User-facing name of this repository, for references to sibling repositories such as the toolchains repository.",
            default = "npm_typescript",
        ),
        "version": attr.string(doc = "Explicit version for `urls` placeholder. If provided, the package.json is not read."),
        "urls": attr.string_list(doc = "URLs to fetch from. Each must have one `{}`-style placeholder."),
        "_build_file": attr.label(
            doc = "The BUILD file to write into the created repository.",
            default = Label("@aspect_rules_ts//ts:BUILD.typescript"),
        ),
        "version_from": attr.label(doc = "Location of package.json which may have a version for the package."),
    },
)

# buildifier: disable=function-docstring
def npm_dependencies(name = "npm_typescript", ts_version_from = None, ts_version = None, ts_integrity = None):
    if (ts_version and ts_version_from) or (not ts_version_from and not ts_version):
        fail("""Exactly one of 'ts_version' or 'ts_version_from' must be set.""")

    maybe(
        http_archive_version,
        name = name,
        repo_name = name,
        version = ts_version,
        version_from = ts_version_from,
        integrity = ts_integrity,
        urls = ["https://registry.npmjs.org/typescript/-/typescript-{}.tgz"],
    )
