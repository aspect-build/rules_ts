"""Runtime dependencies fetched from npm"""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//ts/private:versions.bzl", "RULES_TS_VERSION", "TOOL_VERSIONS")

worker_versions = struct(
    bazel_worker_version = "5.4.2",
    bazel_worker_integrity = "sha512-wQZ1ybgiCPkuITaiPfh91zB/lBYqBglf1XYh9hJZCQnWZ+oz9krCnZcywI/i1U9/E9p3A+4Y1ni5akAwTMmfUA==",
    google_protobuf_version = "3.20.1",
    google_protobuf_integrity = "sha512-XMf1+O32FjYIV3CYu6Tuh5PNbfNEU5Xu22X+Xkdb/DUexFlCzhvv7d5Iirm4AOwn8lv4al1YvIhzGrg2j9Zfzw==",
)

# Keep this list in sync with user documentation.
# We must inform users what we gather from their builds.
_TELEMETRY_VARS = [
    "BUILDKITE_ORGANIZATION_SLUG",
    "CIRCLE_PROJECT_USERNAME",
    "GITHUB_REPOSITORY_OWNER",
    "BUILDKITE_BUILD_NUMBER",
    "CIRCLE_BUILD_NUM",
    "GITHUB_RUN_NUMBER",
]

def _http_archive_version_impl(rctx):
    integrity = None
    if rctx.attr.version:
        version = rctx.attr.version
    else:
        json_path = rctx.path(rctx.attr.version_from)
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
        if any([not seg.isdigit() for seg in ts.split(".")]):
            fail("""typescript version in package.json must be exactly specified, not a semver range: %s.
            You can supply an exact 'ts_version' attribute to 'rules_ts_dependencies' to bypass this check.""" % ts)
        version = ts

    if integrity:
        pass
    elif rctx.attr.integrity:
        integrity = rctx.attr.integrity
    elif version in TOOL_VERSIONS.keys():
        integrity = TOOL_VERSIONS[version]
    else:
        fail("""typescript version {} is not mirrored in rules_ts, is this a real version?
            If so, you must manually set 'ts_integrity'.
            See documentation on rules_ts_dependencies.""".format(version))

    rctx.download_and_extract(
        url = [u.format(version) for u in rctx.attr.urls],
        integrity = integrity,
    )
    build_file_substitutions = {
        "ts_version": version,
        # Note: we can't depend on bazel_skylib because this code is called from
        # rules_ts_dependencies so it's not "in scope" yet.
        # So we can't use versions.bzl to parse the version
        "is_ts_5": str(int(version.split(".")[0]) >= 5),
    }
    build_file_substitutions.update(**rctx.attr.build_file_substitutions)
    rctx.template(
        "BUILD.bazel",
        rctx.path(rctx.attr.build_file),
        substitutions = build_file_substitutions,
        executable = False,
    )

    if rctx.attr.check_for_updates:
        vars = ["{}={}".format(v, rctx.os.environ[v]) for v in _TELEMETRY_VARS if v in rctx.os.environ]
        if rctx.attr.bzlmod:
            vars.append("bzlmod=true")
        url = "https://update.aspect.build/aspect_rules_ts/{}?{}".format(
            RULES_TS_VERSION,
            "&".join(vars),
        )
        output_path = str(rctx.path(".output/update_check_result"))
        command = ["curl", url, "--write-out", "%{http_code}", "--output", output_path]
        result = rctx.execute(command)
        if result.return_code != 0:
            # Ignore failures when trying to check for new version
            return
        status_code = int(result.stdout.strip())
        if status_code != 302:
            # 304: Not Modified means we have the latest version already
            return

        # buildifier: disable=print
        print("NOTICE: a newer version of rules_ts is available")
        # TODO: print content of output_path which now has the link to the newer version

http_archive_version = repository_rule(
    doc = "Re-implementation of http_archive that can read the version from package.json",
    implementation = _http_archive_version_impl,
    attrs = {
        "bzlmod": attr.bool(doc = "Whether we were called from a bzlmod module extension"),
        "check_for_updates": attr.bool(doc = "Whether to check for a newer version of rules_ts"),
        "integrity": attr.string(doc = "Needed only if the ts version isn't mirrored in `versions.bzl`."),
        "version": attr.string(doc = "Explicit version for `urls` placeholder. If provided, the package.json is not read."),
        "urls": attr.string_list(doc = "URLs to fetch from. Each must have one `{}`-style placeholder."),
        "build_file": attr.label(doc = "The BUILD file to write into the created repository."),
        "build_file_substitutions": attr.string_dict(doc = "Substitutions to make when expanding the BUILD file."),
        "version_from": attr.label(doc = "Location of package.json which may have a version for the package."),
    },
)

# buildifier: disable=function-docstring
def npm_dependencies(ts_version_from = None, ts_version = None, ts_integrity = None, bzlmod = False, check_for_updates = True):
    if (ts_version and ts_version_from) or (not ts_version_from and not ts_version):
        fail("""Exactly one of 'ts_version' or 'ts_version_from' must be set.""")

    maybe(
        http_archive_version,
        name = "npm_typescript",
        bzlmod = bzlmod,
        check_for_updates = check_for_updates,
        version = ts_version,
        version_from = ts_version_from,
        integrity = ts_integrity,
        build_file = "@aspect_rules_ts//ts:BUILD.typescript",
        build_file_substitutions = {
            "bazel_worker_version": worker_versions.bazel_worker_version,
            "google_protobuf_version": worker_versions.google_protobuf_version,
        },
        urls = ["https://registry.npmjs.org/typescript/-/typescript-{}.tgz"],
    )
