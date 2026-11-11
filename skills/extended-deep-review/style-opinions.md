# Style Opinions

The personal style opinions enforced by the `styling` specialist in
the `extended-deep-review` skill. This file is the single source of
truth — edit it freely to add, change, or remove opinions; no other
file needs to change.

Format: one `##` section per area, one `###` subsection per opinion.
Keep each opinion short and actionable: what to prefer, when it
applies, and what to recommend when violated.

Opinions come in two tiers:

- **Flag** (post as `SUGGESTION`): hard rules the reviewer always
  enforces.
- **Mention** (post as `NOTE`): softer preferences the reviewer raises
  when relevant.

Do not add generic style or lint-level commentary beyond these
opinions. Most examples are Go, but the same principles apply across
the stack (CI config, Dockerfiles, frontend, shell, docs).

## Naming

### Flag: function names must describe actual behavior

If a function selects among options, name it `determine*`, not
`validate*`. If it only returns open regressions, name it
`ListOpenRegressions`, not `ListRegressions`. Require the rename.

### Flag: test function names must match the function under test

`TestFoo` tests `Foo` — not something else.

### Flag: variable names and log messages use consistent terminology

If the variable is `podName`, the log message must say "pod name", not
"container name".

### Flag: typed constants include explicit type annotations

`const Foo MyType = "bar"`, not `const Foo = "bar"`, even when the
type could be inferred.

### Flag: CI job names clearly describe their purpose

Context, name, and description fields for a job should be consistent
with each other.

### Flag: image tags include an explicit version or `latest`

Never leave a container image tag unspecified.

### Mention: extract magic strings and repeated literal values into named constants

Especially when used in multiple places or representing domain
concepts — including repeated inline style values in frontend code.

### Mention: variable names should be descriptive

Flag `x` or over-abbreviated names like `rg` when `regressionGroup`
would be clearer. Don't nitpick reasonable short names in tight
scopes.

### Mention: pluralization correctness

A field named `result` holding a slice should be `results`.

### Mention: constant names precisely describe their scope

`maxDistinctFailures` vs `maxTotalFailures` — precision matters.

### Mention: script files carry appropriate extensions

`.py` for Python, etc.

## Error handling

### Flag: never assign errors to the blank identifier

Every error must be handled or propagated. `_ = doThing()` (or
`foo, _ := ...`) is a hard rule.

### Flag: error messages describe the specific operation that failed

"obtaining repository from github", not "checking". "obtaining org
from github", not "checking". Include specifics: which operation
failed, on which input, which items were not found. Recommend
rewriting the error string.

### Flag: error checks reference a clearly identifiable operation

No orphaned `if err != nil` blocks where the source of `err` is
ambiguous.

### Flag: when iterating, log errors and continue rather than returning early

Process all items, collect failures, report at the end.

### Flag: fatal log messages describe the error condition, not its consequence

Say what went wrong, not what will happen because it went wrong.

### Flag: data mutations must not be silently overwritten

If a value is appended (or otherwise built up) and a subsequent
operation replaces it, that's a bug — flag it.

### Flag: defensive checks for "shouldn't ever happen" conditions

Add them to prevent stack traces in production, even when the
condition seems impossible.

### Mention: prefer failing hard over silently continuing

When a failure would go unnoticed by users, crash rather than
swallow.

### Mention: wrap errors to add context

`errors.Wrap` (or `fmt.Errorf("%w")`) when wrapping deserialization
errors, as a nitpick.

### Mention: log level fidelity

Error-level (not warning) for failed cleanup/removal operations;
`warn` (not `info`) for non-critical fallback conditions.

## Code organization

### Flag: remove dead code

Functions never called, code blocks always overwritten by later
logic, leftovers from previous approaches — all must go. This is the
reviewer's strongest opinion.

### Flag: remove debug logging before merging

### Flag: config merges include ALL relevant fields

A field missing from merge logic is a bug — flag it as required to
fix.

### Flag: use standard library initialization helpers

e.g. `ComponentInit` instead of manually configuring loggers with
redundant options.

### Flag: no tooling or configuration irrelevant to the repository's scope

### Flag: always supply required dependencies like loggers

Never pass `nil` for a logger; don't design APIs that accept nil
loggers.

### Flag: don't modify code slated for removal

Remove it in a separate commit instead.

### Flag: use k8s apimachinery sets when available

When the module already depends on `k8s.io/apimachinery`, set
membership and set operations should use
`k8s.io/apimachinery/pkg/util/sets` (`sets.New[T]()`, `.Has`,
`.Insert`, `.Delete`, `.Union`, `.Intersection`, `.UnsortedList`,
...) instead of ad-hoc alternatives: `map[T]bool`,
`map[string]struct{}` with manual presence checks, linear
`slices.Contains` scans over slices, or nested dedupe loops. Only
recommend the switch when apimachinery is already in the module's
dependency graph (check go.mod or existing imports) — do not suggest
adding the dependency to a module that does not have it.

### Mention: start simple, iterate later

First-pass implementations are fine with a plan to improve ("SGTM for
a first pass"). Encourage filing follow-ups rather than blocking.

### Mention: keep PRs focused

Defer non-critical improvements and unrelated changes to follow-up
PRs; file an issue to track the debt. Suggest splitting when a PR
bundles unrelated work.

### Mention: extract distinct logical operations into named functions

For readability and testability.

### Mention: prefer existing library utilities over shelling out

e.g. prow's `gitClient` over `exec.Command("git", ...)` unless it
would be the only usage.

### Mention: consolidate related computations into a single loop

Rather than iterating the same data multiple times. Similarly, hoist
invariant checks out of inner loops, and hoist common operations out
of conditional branches instead of duplicating them.

### Mention: prefer relying on PATH resolution

Over constructing explicit binary paths.

### Mention: duplication is acceptable for short-lived components

If the code will be removed soon — but note it as temporary.

## Testing

### Flag: test names accurately describe the scenario

Both the function name and the test case name. Grammar matters in
test names.

### Flag: include both positive and negative test cases

Cover all relevant combinations of conditions.

### Flag: unit tests assert ALL relevant properties

Use distinct values to verify behavior — identical values that don't
prove correctness get flagged.

### Flag: preserve deterministic order in ordering-dependent integration tests

### Flag: remove version-based test skips when CI supports the required version

### Flag: always use table-driven testing in Go

New or substantially rewritten Go tests must be table-driven: one
test function iterating over a slice of test-case structs, with
`t.Run` per case. Flag new tests written as one function per case, or
with copy-pasted assertion blocks that a table would collapse. Prefer
`t.Run` subtests with descriptive names so failures identify the
case. Trivial single-case tests may stay simple, but anything with
more than one case should be a table.

### Mention: new code comes with tests

Same PR or a clear plan for follow-up.

### Mention: clean up test case fields when refactoring removes a parameter

### Mention: remove tests that don't add value

Redundant with existing coverage.

### Mention: follow existing testing patterns in the codebase

And document limitations when testing against external services.

## Performance

### Flag: never update immutable database fields

Don't write to fields that never change after creation.

### Mention: compile regular expressions once as package-level variables

Not on each function call.

### Mention: drop redundant string checks before regex operations

The regex already handles the no-match case.

### Mention: cache responses at the client level

When recommended, to avoid redundant network calls.

### Mention: avoid redundant function calls

When the result is the same as the input (e.g. a string replacement
that produces the original).

## Common nitpicks

These are `NOTE`-tier but consistently flagged:

- Whitespace-only changes in unrelated files — keep diffs focused.
- Redundant `return` statements at the end of functions.
- Unnecessary intermediate variables — return the result of the
  conditional check directly.
- Repeated sub-expressions — extract `foo.Bar.Baz` accessed multiple
  times into a local variable.
- Redundant inline comments for struct fields when the name and type
  already convey meaning; comments that restate what the code makes
  obvious.
- Unnecessary articles ("the") in docs when the sentence reads better
  without.
- Typos in comments.
- `var x bool` over `x := false` for idiomatic Go zero-value
  declarations.
- Uncertain markers like `??` in committed comments — express clear
  intent.
