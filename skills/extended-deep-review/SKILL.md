---
name: extended-deep-review
description: Runs the deep-review multi-specialist panel review with one additional specialist — an opinionated styling reviewer that enforces the personal style opinions defined in style-opinions.md (currently: table-driven testing in Go, k8s apimachinery sets). Use when the user asks for a deep review that also applies their personal style opinions, or invokes extended-deep-review.
---

# Deep Review + Opinionated Styling

This skill is a wrapper around the existing `deep-review` skill (the
multi-specialist panel review from the `code-review` plugin). Run the
deep-review procedure exactly as defined, with one addition: an extra
panel specialist, **styling**, which enforces the personal style
opinions in [style-opinions.md](style-opinions.md).

## Procedure

1. Locate the `deep-review` skill in the current tool — however this
   tool exposes it (a `deep-review` skill, the `code-review` plugin's
   `deep-review` skill, or `/code-review:deep-review`). Read its
   SKILL.md.
2. Execute that procedure **exactly as written**, with only the
   modifications in "The styling specialist" below. Forward all
   arguments unchanged — flags (`--serial`, `--comment`,
   `--coderabbit`, `--codex`), `-reviewer` exclusions, and PR/MR
   identifiers all pass through to deep-review.

## The styling specialist

Add `styling` to the specialist roster alongside bugs, adversarial,
security, architecture, consistency, qa, and writer. It participates
in every phase like any other specialist:

- **Parallel mode (default)**: launch it in the same batch as the
  other specialist sub-agents, in a single message.
- **Serial mode (`--serial`)**: run it inline after the other
  specialists, in roster order (last).
- `-styling` excludes it, exactly like any other specialist.
- **Completeness gate**: it must produce findings (or an explicit "no
  issues" with what was checked); re-dispatch once on failure like
  the others.
- **Panel arbiter**: treat it as a peer specialist — deduplicate and
  synthesize its findings with the rest. Do **not** filter its
  findings out as "style nitpicks": they are explicitly requested
  opinions. However, styling findings must never affect the
  disposition — they cannot make a review REQUEST_CHANGES.

### Styling specialist prompt

Before dispatch, resolve the absolute path of `style-opinions.md` in
this skill's directory (the directory containing this SKILL.md). Give
the styling sub-agent — or apply inline, in serial mode — this
prompt, with `<style-opinions-path>` replaced by that absolute path:

> You are an opinionated styling reviewer. Read
> `<style-opinions-path>` — those are the style opinions you enforce.
> Review the branch's changes strictly through that lens: flag any
> changed code that violates an opinion, cite the opinion by its
> heading, and suggest the opinion-preferred alternative. Only flag
> things that an opinion in that file covers — no generic style
> commentary, no lint-level nitpicks. You may read the surrounding
> codebase for context (existing helpers, imports, go.mod) to judge
> whether an opinion applies. You MUST NOT modify any files, and MUST
> NOT run remote-write git commands. Read-only review only.
>
> Return findings in the same JSON schema as the other specialists,
> with `reproducer_needed: false`. Severity is always `SUGGESTION`
> (or `NOTE` for minor mentions) — never `BLOCKING`.

### Severity

Styling findings are `SUGGESTION` or `NOTE`, never `BLOCKING`. Style
opinions surface in the verdict's Optional Follow-ups, not Required
Actions.

## Editing the opinions

The opinions live in [style-opinions.md](style-opinions.md) next to
this SKILL.md. That file is the single source of truth — edit it to
add, change, or remove opinions; nothing else needs to change. Keep
each opinion short and actionable so the specialist can enforce it.
