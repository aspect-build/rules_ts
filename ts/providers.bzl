"""Providers for rules_ts."""

TscInfo = provider(
    doc = """Encapsulates information about a typescript compiler."""
    fields = {
        "tsc": "Typescript compiler binary (required)",
        "tsc_worker": "Typescript compiler worker",
        "validator": "Validator binary (required)",
        "is_typescript_5_or_greater": "Whether typescript version is known to be greater than 5.",
    },
)

def tsc_info(tsc, tsc_worker = None, validator = None, is_typescript_5_or_greater = False):
    # TODO:
    # - Argument validation
    # - Take default validator if it is not set? Is this the right place for it?
    return TscInfo(
        tsc = tsc,
        tsc_worker = tsc_worker,
        validator = validator,
        is_typescript_5_or_greater = is_typescript_5_or_greater,
    )
