package gazelle

import (
	"github.com/bazelbuild/bazel-gazelle/rule"
)

const (
	tsProjectKind = "ts_project"
)

// Kinds returns a map that maps rule names (kinds) and information on how to
// match and merge attributes that may be found in rules of those kinds.
func (*TypeScript) Kinds() map[string]rule.KindInfo {
	return tsKinds
}

var tsKinds = map[string]rule.KindInfo{
	tsProjectKind: {
		MatchAny: false,
		NonEmptyAttrs: map[string]bool{
			"srcs": true,
		},
		SubstituteAttrs: map[string]bool{},
		MergeableAttrs: map[string]bool{
			"srcs": true,
		},
		ResolveAttrs: map[string]bool{
			"deps": true,
		},
	},
}

// Loads returns .bzl files and symbols they define. Every rule generated by
// GenerateRules, now or in the past, should be loadable from one of these
// files.
func (ts *TypeScript) Loads() []rule.LoadInfo {
	return tsLoads
}

var tsLoads = []rule.LoadInfo{
	{
		// TODO: @aspect_rules_ts is a variable. Get from a flag?
		Name: "@aspect_rules_ts//ts:defs.bzl",
		Symbols: []string{
			tsProjectKind,
		},
	},
}
