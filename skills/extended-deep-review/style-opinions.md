# Style Opinions

The personal style opinions enforced by the `styling` specialist in
the `extended-deep-review` skill. This file is the single source of
truth — edit it freely to add, change, or remove opinions; no other
file needs to change.

Format: one `##` section per language or area, one `###` subsection
per opinion. Keep each opinion short and actionable: what to prefer,
when it applies, and what to recommend when violated.

## Go

### Always use table-driven testing in golang

New or substantially rewritten Go tests must be table-driven: one
test function iterating over a slice of test-case structs, with
`t.Run` per case. Flag new tests written as one function per case, or
with copy-pasted assertion blocks that a table would collapse.
Prefer `t.Run` subtests with descriptive names so failures identify
the case. Trivial single-case tests may stay simple, but anything
with more than one case should be a table.

### Use k8sapimachinery sets when available

When the module already depends on `k8s.io/apimachinery`, set
membership and set operations should use
`k8s.io/apimachinery/pkg/util/sets` (`sets.New[T]()`, `.Has`,
`.Insert`, `.Delete`, `.Union`, `.Intersection`, `.UnsortedList`,
...) instead of ad-hoc alternatives: `map[T]struct{}` with manual
presence checks, linear `slices.Contains` scans over slices, or
nested dedupe loops. Only recommend the switch when apimachinery is
already in the module's dependency graph (check go.mod or existing
imports) — do not suggest adding the dependency to a module that
does not have it.
