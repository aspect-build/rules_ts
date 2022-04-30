load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

def ts_my_project(name, **kwargs) {
    ts_project(name, **kwargs)
}