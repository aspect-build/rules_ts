load("@aspect_rules_ts//ts/private:versions.bzl", "VERSIONS")

# simple semver version parser. 
# only supports <version core> portion of SemVer specification.
# does not perform any validation on SemVer parts.
# https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions
def semver_parse(version_str):
    parts = version_str.split(".")
    if len(parts) > 3:
        fail("semver_parse does not support semver strings that have more than <version core> SemVer strings.")
    return parts

def _cmp(a, b):
    """Return negative if a<b, zero if a==b, positive if a>b."""
    return int(a > b) - int(a < b)

def semver_compare(version_str, compared_str):
    """Returns 1 if version_str is greater than compared_str, 0 if equals, and -1 if less.""" 
    version = semver_parse(version_str)
    compared = semver_parse(compared_str)
    return _cmp(version, compared)

def semver_gt(version_str, compared_str):
    return semver_compare(version_str, compared_str) == 1

SUPPORTED_VERSIONS = [
    version
    for version in VERSIONS.keys()
    if semver_gt(version, "4.0.8")
]