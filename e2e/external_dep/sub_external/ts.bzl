"""
Util for hiding ts_project() workaround for  https://github.com/aspect-build/rules_ts/issues/483
"""

load("@aspect_rules_ts//ts:defs.bzl", _ts_project = "ts_project")

def ts_project(name, **kwargs):
    _ts_project(
        name = name,
        tsc = "@npm_typescript2//:tsc",
        tsc_worker = "@npm_typescript2//:tsc_worker",
        validator = "@npm_typescript2//:validator",
        **kwargs
    )
