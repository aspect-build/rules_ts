load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load(":versions.bzl", "SUPPORTED_VERSIONS")

[
    (
        write_file(
            name = "gen_ts_%s" % version,
            out = "foo_%s.ts" % version,
            content = ["export const a = 1;"],
        ),
        ts_project(
            name = "ts_%s" % version,
            srcs = ["foo_%s.ts" % version],
            declaration = True,
            tsc = "@tsc_%s//:tsc" % version,
            tsc_worker = "@tsc_%s//:tsc_worker" % version,
            validator = "@tsc_%s//:validator" % version,
        )
    )
    for version in SUPPORTED_VERSIONS
]
