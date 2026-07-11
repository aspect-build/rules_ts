#!/usr/bin/env bash
# Check that ts_project attributes match the tsconfig.json properties:
# resolve the tsconfig `extends` chain with `tsc --showConfig` and compare
# the flattened result against the attributes.
#
# Usage:
#   ts_project_options_validator.sh <jq> <tsc> <wrapper_bin_path> <extends> <output_marker> <target_label> <tsconfig_dir> <attr>=<value>...
#
# <wrapper_bin_path> (a declared output this script writes, relative to
# $BAZEL_BINDIR) is a tsconfig extending the real tsconfig at <extends>,
# placed in the tsconfig's own directory so tsc resolves relative paths and
# ${configDir} the same way the compile action does; its `files: []`
# suppresses the TS18003 error tsc otherwise raises because srcs are not
# inputs to this action. <tsconfig_dir> is the directory of the tsconfig
# relative to the ts_project package (empty when the tsconfig is in the
# package directory, or lives outside the package and the wrapper re-roots
# resolved paths to the package). Boolean attribute values are "true"/"false".
set -o errexit -o nounset -o pipefail

jq="$1"
tsc="$2"
wrapper_bin_path="$3"
extends="$4"
marker="$5"
target="$6"
prefix="$7"
shift 7

allow_js=false
composite=false
declaration=false
declaration_dir=
declaration_dir_overridden=false
declaration_map=false
emit_declaration_only=false
incremental=false
isolated_typecheck=false
no_emit=false
out_dir=
out_dir_overridden=false
preserve_jsx=false
resolve_json_module=false
root_dir=
source_map=false
ts_build_info_file=
ts_build_info_file_overridden=false

for arg in "$@"; do
	value="${arg#*=}"
	case "$arg" in
	allow_js=*) allow_js="$value" ;;
	composite=*) composite="$value" ;;
	declaration=*) declaration="$value" ;;
	declaration_dir=*) declaration_dir="$value" ;;
	declaration_dir_overridden=*) declaration_dir_overridden="$value" ;;
	declaration_map=*) declaration_map="$value" ;;
	emit_declaration_only=*) emit_declaration_only="$value" ;;
	incremental=*) incremental="$value" ;;
	isolated_typecheck=*) isolated_typecheck="$value" ;;
	no_emit=*) no_emit="$value" ;;
	out_dir=*) out_dir="$value" ;;
	out_dir_overridden=*) out_dir_overridden="$value" ;;
	preserve_jsx=*) preserve_jsx="$value" ;;
	resolve_json_module=*) resolve_json_module="$value" ;;
	root_dir=*) root_dir="$value" ;;
	source_map=*) source_map="$value" ;;
	ts_build_info_file=*) ts_build_info_file="$value" ;;
	ts_build_info_file_overridden=*) ts_build_info_file_overridden="$value" ;;
	*)
		echo "ERROR: ts_project_options_validator.sh: unknown argument: $arg" >&2
		exit 1
		;;
	esac
done

# Print an error message followed by the ways to suppress validation, then fail.
die() {
	echo "$@" >&2
	echo >&2
	echo "Or to suppress this error, either:" >&2
	echo " - pass --norun_validations to Bazel to turn off the feature completely, or" >&2
	echo " - disable validation for this target by running:" >&2
	echo "    npx @bazel/buildozer 'set validate False' $target" >&2
	exit 1
}

# BAZEL_BINDIR is set by the action: tsc is a js_binary which runs in it,
# while this script and its output redirection run in the execroot.
printf '{"extends": "%s", "files": []}\n' "$extends" >"$BAZEL_BINDIR/$wrapper_bin_path"

resolved="$marker.tmp"

# tsc prints config diagnostics (e.g. TS5083 for a broken extends chain) to
# stdout, which would otherwise disappear into the redirected output file.
if ! "$tsc" --project "$wrapper_bin_path" --showConfig >"$resolved"; then
	cat "$resolved" >&2
	echo >&2
	die "ERROR: failed to resolve the tsconfig file of $target for validation.
If the tsconfig extends a package from npm, that package must be a dependency
of the ts_project(tsconfig) target or ts_config(deps) so it is an input here."
fi

# jq produces no output for an empty input document, so guard separately.
if ! [ -s "$resolved" ]; then
	die "ERROR: tsc --showConfig printed no output for the tsconfig of $target, so it cannot be validated."
fi

# `pwd -W` prints the Windows-style path that tsc uses on that platform.
execroot="$(pwd -W 2>/dev/null || pwd)/"

# Extract the checked properties in a single jq pass. `//` folds both null
# (option not set anywhere in the tsconfig chain) and false to "false", which
# matches how the checks treat an unset option. Options implied rather than
# set are materialized by tsc in the resolved config (e.g. composite implies
# declaration and incremental).
#
# has_exclude means the config chain sets a user-authored "exclude": when the
# config sets none of its own but outDir/declarationDir is set, tsc
# materializes an implicit exclude of absolute (execroot-prefixed) entries,
# while user-authored entries print as written. An exclude consisting solely
# of absolute entries is therefore materialized, not user-authored. (A
# user-authored exclude containing only `${configDir}`-absolute entries is
# misclassified; that combination has no known use.)
cfg="$(
	"$jq" -r --arg p "$execroot" '
        "has_exclude=\(has("exclude") and (.exclude == [] or ([.exclude[] | select(startswith($p) | not)] != [])))",
        (.compilerOptions // {} |
            "allowJs=\(.allowJs // false)",
            "checkJs=\(.checkJs // false)",
            "composite=\(.composite // false)",
            "declaration=\(.declaration // false)",
            "declarationDir=\(.declarationDir // "")",
            "declarationMap=\(.declarationMap // false)",
            "emitDeclarationOnly=\(.emitDeclarationOnly // false)",
            "incremental=\(.incremental // false)",
            "isolatedDeclarations=\(.isolatedDeclarations // false)",
            "jsx=\(.jsx // "")",
            "module=\(.module // "")",
            "moduleResolution=\(.moduleResolution // "")",
            "noEmit=\(.noEmit // false)",
            "outDir=\(.outDir // "")",
            "preserveSymlinks=\(.preserveSymlinks // false)",
            "resolveJsonModule=\(.resolveJsonModule // false)",
            "rootDir=\(.rootDir // "")",
            "sourceMap=\(.sourceMap // false)",
            "tsBuildInfoFile=\(.tsBuildInfoFile // "")"
        )
    ' "$resolved"
)" || die "ERROR: the resolved tsconfig of $target is not valid JSON, so it cannot be validated."

while IFS= read -r line; do
	value="${line#*=}"
	case "$line" in
	has_exclude=*) cfg_has_exclude="$value" ;;
	allowJs=*) cfg_allow_js="$value" ;;
	checkJs=*) cfg_check_js="$value" ;;
	composite=*) cfg_composite="$value" ;;
	declaration=*) cfg_declaration="$value" ;;
	declarationDir=*) cfg_declaration_dir="$value" ;;
	declarationMap=*) cfg_declaration_map="$value" ;;
	emitDeclarationOnly=*) cfg_emit_declaration_only="$value" ;;
	incremental=*) cfg_incremental="$value" ;;
	isolatedDeclarations=*) cfg_isolated_declarations="$value" ;;
	jsx=*) cfg_jsx="$value" ;;
	module=*) cfg_module="$value" ;;
	moduleResolution=*) cfg_module_resolution="$value" ;;
	noEmit=*) cfg_no_emit="$value" ;;
	outDir=*) cfg_out_dir="$value" ;;
	preserveSymlinks=*) cfg_preserve_symlinks="$value" ;;
	resolveJsonModule=*) cfg_resolve_json_module="$value" ;;
	rootDir=*) cfg_root_dir="$value" ;;
	sourceMap=*) cfg_source_map="$value" ;;
	tsBuildInfoFile=*) cfg_ts_build_info_file="$value" ;;
	esac
done <<<"$cfg"

# Normalize a path for comparison: drop "." and empty segments and collapse
# ".." into the preceding segment. The package directory itself normalizes to
# the empty string, matching an unset ts_project attribute. A result of ".."
# (or deeper) means the path escapes the directory it is relative to.
normalize_path() {
	local input="$1" result="" part
	local IFS=/
	for part in $input; do
		case "$part" in
		"" | .) ;;
		..)
			case "$result" in
			"" | .. | */..) result="${result:+$result/}.." ;;
			*/*) result="${result%/*}" ;;
			*) result="" ;;
			esac
			;;
		*) result="${result:+$result/}$part" ;;
		esac
	done
	printf '%s' "$result"
}

failures=""
buildozer=""

add_failure() {
	failures="$failures - $1
"
}

add_buildozer() {
	buildozer="$buildozer '$1'"
}

check_bool() { # <tsconfig option> <tsconfig value> <ts_project attribute> <attribute value>
	if [ "$2" = "$4" ]; then
		return 0
	fi
	# tsc materializes options *implied* by other options in --showConfig
	# output, so accept unset attributes for the checked options with an
	# implication: composite implies declaration and incremental, checkJs
	# implies allowJs, and module preserve / moduleResolution bundler /
	# module nodenext (TypeScript 5.9+) imply resolveJsonModule.
	if [ "$2" = "true" ]; then
		case "$1" in
		declaration | incremental)
			if [ "$cfg_composite" = "true" ]; then
				return 0
			fi
			;;
		allowJs)
			if [ "$cfg_check_js" = "true" ]; then
				return 0
			fi
			;;
		resolveJsonModule)
			case "$cfg_module" in
			nodenext | preserve) return 0 ;;
			esac
			if [ "$cfg_module_resolution" = "bundler" ]; then
				return 0
			fi
			;;
		esac
	fi
	add_failure "attribute $3=$4 does not match compilerOptions.$1=$2"
	if [ "$2" = "true" ]; then
		add_buildozer "set $3 True"
	else
		add_buildozer "set $3 False"
	fi
}

# Directory options like outDir affect where Bazel must predict output files,
# so when the tsconfig sets one, the matching attribute is required to agree.
# When the tsconfig doesn't set it, any attribute value is accepted since
# ts_project passes the attribute to tsc on the command line.
#
# The tsconfig value is compared in the package's space: relative to the
# tsconfig directory as tsc resolves it, then rebased onto the package
# directory, which is how the attribute is expressed. When the attribute
# drives a tsc command-line flag that overrides the tsconfig value at compile
# time (<overridden> = true), a match in the tsconfig directory's own space is
# also accepted: the values then express the same name and the attribute is
# the one that takes effect.
check_dir() { # <tsconfig option> <tsconfig value> <ts_project attribute> <attribute value> <overridden>
	if [ -z "$2" ]; then
		return 0
	fi
	local rebased want
	rebased="$(normalize_path "$prefix/$2")"
	case "$rebased" in
	.. | ../*)
		die "The $1 in the tsconfig resolves to \"$rebased\" which is a parent of the package directory.

This is not supported by ts_project because all output files must be within
the package output directory.

If your tsconfig is shared from a parent directory, set $1 in that
tsconfig to a path at or below the package, or use the $3 attribute
on ts_project to override it."
		;;
	esac
	want="$(normalize_path "$4")"
	if [ "$want" = "$rebased" ]; then
		return 0
	fi
	if [ "$5" = "true" ] && [ -n "$want" ] && [ "$want" = "$(normalize_path "$2")" ]; then
		return 0
	fi
	die "When $1 is set in the tsconfig it must also be set in the ts_project rule using $3, so that the output directory is known to Bazel.

tsconfig:   $rebased
ts_project: ${4:-<unset>}"
}

if [ "$cfg_preserve_symlinks" = "true" ]; then
	die "ERROR: ts_project rule $target cannot be built because the 'preserveSymlinks' option is set.
This is not compatible with ts_project due to the rules_js use of symlinks."
fi

check_bool allowJs "$cfg_allow_js" allow_js "$allow_js"
check_bool declarationMap "$cfg_declaration_map" declaration_map "$declaration_map"
check_bool noEmit "$cfg_no_emit" no_emit "$no_emit"
check_bool emitDeclarationOnly "$cfg_emit_declaration_only" emit_declaration_only "$emit_declaration_only"
check_bool resolveJsonModule "$cfg_resolve_json_module" resolve_json_module "$resolve_json_module"
check_bool sourceMap "$cfg_source_map" source_map "$source_map"
check_bool composite "$cfg_composite" composite "$composite"
check_bool declaration "$cfg_declaration" declaration "$declaration"
check_bool incremental "$cfg_incremental" incremental "$incremental"
check_dir outDir "$cfg_out_dir" out_dir "$out_dir" "$out_dir_overridden"
check_dir declarationDir "$cfg_declaration_dir" declaration_dir "$declaration_dir" "$declaration_dir_overridden"
# --rootDir is always passed on the tsc command line.
check_dir rootDir "$cfg_root_dir" root_dir "$root_dir" true
check_dir tsBuildInfoFile "$cfg_ts_build_info_file" ts_build_info_file "$ts_build_info_file" "$ts_build_info_file_overridden"

# Guard against https://github.com/microsoft/TypeScript/issues/59036, see
# https://github.com/aspect-build/rules_ts/issues/644. has_exclude excludes
# tsc-materialized (implicit) entries, so it is true only for a user-authored
# "exclude", wherever in the extends chain it was set.
if [ -n "$root_dir" ] && [ -z "$out_dir" ] && [ "$cfg_has_exclude" != "true" ]; then
	die "When root dir is set, exclude must also be set to empty array in the tsconfig file.

For example, tsconfig.json:
{
   \"exclude\": []
}

See tickets: https://github.com/microsoft/TypeScript/issues/59036 and
https://github.com/aspect-build/rules_ts/issues/644"
fi

if [ "$isolated_typecheck" = "true" ] && [ "$cfg_isolated_declarations" != "true" ]; then
	add_failure "attribute isolated_typecheck=true requires compilerOptions.isolatedDeclarations=true
   See documentation on ts_project(isolated_typecheck) for more info"
	add_buildozer "set isolated_typecheck False"
fi

if [ "$cfg_jsx" = "preserve" ]; then
	jsx_preserve=true
else
	jsx_preserve=false
fi
if [ "$jsx_preserve" != "$preserve_jsx" ]; then
	add_failure "attribute preserve_jsx=$preserve_jsx does not match compilerOptions.jsx=${cfg_jsx:-none}"
	if [ "$jsx_preserve" = "true" ]; then
		add_buildozer "set preserve_jsx True"
	else
		add_buildozer "set preserve_jsx False"
	fi
fi

if [ -n "$failures" ]; then
	echo "ERROR: ts_project rule $target was configured with attributes that don't match the tsconfig" >&2
	printf '%s' "$failures" >&2
	echo "You can automatically fix this by running:" >&2
	echo "    npx @bazel/buildozer$buildozer $target" >&2
	echo "Or to suppress this error, either:" >&2
	echo " - pass --norun_validations to Bazel to turn off the feature completely, or" >&2
	echo " - disable validation for this target by running:" >&2
	echo "    npx @bazel/buildozer 'set validate False' $target" >&2
	exit 1
fi

# Bazel validation actions must produce an output file.
# Make the output change whenever the attributes change.
printf '// checked attributes for %s\n' "$target" >"$marker"
printf '// %s\n' "$@" >>"$marker"
