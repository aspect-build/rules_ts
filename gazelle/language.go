package gazelle

import (
	"github.com/bazelbuild/bazel-gazelle/language"
)

const languageName = "TypeScript"

// The Gazelle extension for TypeScript rules.
// TypeScript satisfies the language.Language interface, including the Resolver subtype
// and containing the Configurer
type TypeScript struct {
	Configurer
}

// NewLanguage initializes a new TypeScript that satisfies the language.Language
// interface. This is the entrypoint for the extension initialization.
func NewLanguage() language.Language {
	return &TypeScript{}
}
