"""Runtime dependencies fetched from npm"""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//ts/private:maybe.bzl", http_archive = "maybe_http_archive")
load("//ts/private:versions.bzl", "TOOL_VERSIONS")

versions = struct(
    rules_nodejs = "5.5.0",
)

worker_versions = struct(
    bazel_worker_version = "5.4.2",
    bazel_worker_integrity = "sha512-wQZ1ybgiCPkuITaiPfh91zB/lBYqBglf1XYh9hJZCQnWZ+oz9krCnZcywI/i1U9/E9p3A+4Y1ni5akAwTMmfUA==",
    google_protobuf_version = "3.20.1",
    google_protobuf_integrity = "sha512-XMf1+O32FjYIV3CYu6Tuh5PNbfNEU5Xu22X+Xkdb/DUexFlCzhvv7d5Iirm4AOwn8lv4al1YvIhzGrg2j9Zfzw==",
)

def _http_archive_version_impl(rctx):
    if rctx.attr.version:
        version = rctx.attr.version
    else:
        json_path = rctx.path(rctx.attr.version_from)
        p = json.decode(rctx.read(json_path))
        if "devDependencies" in p.keys() and "typescript" in p["devDependencies"]:
            ts = p["devDependencies"]["typescript"]
        elif "dependencies" in p.keys() and "typescript" in p["dependencies"]:
            ts = p["dependencies"]["typescript"]
        else:
            fail("key 'typescript' not found in either dependencies or devDependencies of %s" % json_path)
        if any([not seg.isdigit() for seg in ts.split(".")]):
            fail("""typescript version in package.json must be exactly specified, not a semver range: %s.
            You can supply an exact 'ts_version' attribute to 'rules_ts_dependencies' to bypass this check.""" % ts)
        version = ts

    if rctx.attr.integrity:
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
    build_file_substitutions = {"ts_version": version}
    build_file_substitutions.update(**rctx.attr.build_file_substitutions)
    rctx.template(
        "BUILD.bazel",
        rctx.path(rctx.attr.build_file),
        substitutions = build_file_substitutions,
        executable = False,
    )

http_archive_version = repository_rule(
    doc = "Re-implementation of http_archive that can read the version from package.json",
    implementation = _http_archive_version_impl,
    attrs = {
        "integrity": attr.string(doc = "Needed only if the ts version isn't mirrored in `versions.bzl`."),
        "version": attr.string(doc = "Explicit version for `urls` placeholder. If provided, the package.json is not read."),
        "urls": attr.string_list(doc = "URLs to fetch from. Each must have one `{}`-style placeholder."),
        "build_file": attr.label(doc = "The BUILD file to write into the created repository."),
        "build_file_substitutions": attr.string_dict(doc = "Substitutions to make when expanding the BUILD file."),
        "version_from": attr.label(doc = "Location of package.json which may have a version for the package."),
    },
)

# buildifier: disable=function-docstring
def npm_dependencies(ts_version_from = None, ts_version = None, ts_integrity = None):
    if (ts_version and ts_version_from) or (not ts_version_from and not ts_version):
        fail("""Exactly one of 'ts_version' or 'ts_version_from' must be set.""")

    http_archive(
        name = "npm_google_protobuf",
        build_file = "@aspect_rules_ts//ts:BUILD.package",
        integrity = worker_versions.google_protobuf_integrity,
        urls = ["https://registry.npmjs.org/google-protobuf/-/google-protobuf-{}.tgz".format(worker_versions.google_protobuf_version)],
    )

    http_archive(
        name = "npm_at_bazel_worker",
        integrity = worker_versions.bazel_worker_integrity,
        build_file = "@aspect_rules_ts//ts:BUILD.package",
        urls = ["https://registry.npmjs.org/@bazel/worker/-/worker-{}.tgz".format(worker_versions.bazel_worker_version)],
    )

    maybe(
        http_archive_version,
        name = "npm_typescript",
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
