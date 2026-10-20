# Monitor pull requests for new comments — `/monitor-pr` command definition

This file is the single source of truth for the `/monitor-pr` command.
User-level command stubs in Claude Code (`~/.claude/commands/`), Cursor
(`~/.cursor/commands/`), OpenCode (`~/.config/opencode/commands/`), and
Codex (`~/.codex/skills/monitor-pr/`) reference this file rather than
duplicating it.

---

## Usage

`/monitor-pr [<interval>] [<duration>] <pr-reference> [<pr-reference>...]`

- `<interval>` — how often to check: `30s`, `10m`, `1h`. Defaults to `10m`.
- `<duration>` — how long to monitor: `45m`, `2h`, `1d`. Defaults to `6h`.
- `<pr-reference>` — a GitHub pull request URL
  (`https://github.com/owner/repo/pull/123`) or shorthand `owner/repo#123`.
  Any mix of PRs from any repositories.

Both timing arguments may be omitted; the defaults are a **10 minute
interval over 6 hours** (36 ticks). A PR reference is always required —
an argument is treated as a timing parameter only when it parses as one
(`30s`, `10m`, `1h`, `45m`, `2h`, `1d`, and similar), so the command
works in any argument order for the timing values. When in doubt, ask.

Examples:

- `/monitor-pr 10m 2h openshift/sippy#4121 https://github.com/openshift/origin/pull/31775`
- `/monitor-pr openshift/sippy#4121` — monitors with the 10m / 6h defaults
- `/monitor-pr 30m 1d owner/repo#42`

## Rules that always apply

- Never push, never post a comment or review reply, and never modify any
  remote state until I have explicitly confirmed. Drafting local changes
  and reply text is fine; publishing anything is not.
- Never force-push.
- Give me a short status update on every tick, even when nothing changed.
- Alert me prominently whenever there is something actionable, and pause
  for my confirmation before publishing anything. Every such alert also
  sends a desktop notification — see **Notifications** below.
- Stop the loop when the duration elapses, when I ask you to stop, or when
  every monitored PR has merged or closed. Say which of these ended it.

## Notifications

In addition to the in-session alert, send a desktop notification
whenever the monitor needs me or has taken an action:

- Actionable comments arrived and drafts are ready for my review (send it
  before pausing at the confirmation gate).
- I confirmed and you published a push or reply (include what was
  published and where).
- A monitored PR merged or closed, or a required CI check failed.
- Monitoring ended.

When the session runs on the macOS host, use:

```sh
osascript -e 'display notification "Sippy #4121: 2 new comments, drafts ready for review" with title "monitor-pr" sound name "default"'
```

Keep the text short: what happened, which PR, and whether input is
needed. Inside a devcontainer there is no `osascript`; emit the terminal
bell (`printf '\a'`) instead, which notifies in terminals configured to
alert on bell. If your agent tool has a built-in notification or alert
feature, prefer enabling that as well. Notifications are best-effort: if
a notification command fails or the environment cannot surface one, rely
on the in-session alert and continue — never let a notification failure
break a tick. Do not notify for routine no-change ticks or bot noise.

## Steps

### 1. Parse arguments and validate the PRs

Apply the defaults for omitted timing arguments: interval `10m`, duration
`6h`. Convert the interval and duration to seconds and compute the stop
time. For each PR reference, resolve it with:

```sh
gh pr view https://github.com/{owner}/{repo}/pull/{number} --json number,state,author,headRefName,headRefOid,headRepositoryOwner,url
```

Normalize `owner/repo#123` shorthand to its full URL first; `gh pr view`
needs the URL form (or `--repo {owner}/{repo}` with the bare number) when
the session is not inside that repository. If a PR is already closed or
merged, report that and exclude it. If a reference fails to resolve,
report the error and continue with the rest. If no PRs remain, stop.

### 2. Baseline check

For each PR, fetch the current activity (normalize references to URLs as
in step 1):

```sh
gh pr view <url> --json comments,reviews,statusCheckRollup
gh api repos/{owner}/{repo}/pulls/{number}/comments
```

The second command lists inline review comments. Record the IDs of all
comments, reviews, and review comments as the seen-baseline. Report the
baseline: per PR, state, CI status, and existing discussion. If there are
pre-existing comments from anyone other than me and known bots, ask me
whether to act on them now or treat them as baseline and only act on
comments that arrive after monitoring starts.

### 3. Arm the recurring check

Arm one recurring wake-up every `<interval>` using your tool's
background-task or scheduling capability, so each tick arrives as a
notification rather than blocking the session. A portable bash pattern:

```bash
i=0; total=<ticks>; while [ "$i" -lt "$total" ]; do sleep <seconds>; i=$((i+1)); printf 'AGENT_LOOP_TICK_monitor_pr {"tick":"%s"}\n' "$i"; done
```

Run it as a background task with output notifications enabled and act on
each `AGENT_LOOP_TICK_monitor_pr` line. `<ticks>` is the duration divided
by the interval. If your tool cannot notify on background output, run the
checks inline with a `sleep <interval>` between ticks instead. Arm
exactly one loop; if one is already running for this purpose, reuse it
and do not arm a second.

Tell me the interval, the duration, when monitoring will stop, and the
PR list.

### 4. On each tick

For each still-open PR, fetch comments, reviews, inline review comments,
and CI status as in step 2, and compare against the seen-baseline:

- New items authored by me: mark seen, mention briefly.
- Bot noise (openshift-ci, openshift-ci-robot, openshift-merge-bot,
  k8s-ci-robot, github-actions, and similar bots; approval notifiers,
  lifecycle-plugin and pipeline-controller notices): mark seen and
  summarize in one line. Do not act.
- Bot-generated review findings (such as CodeRabbit) and anything from
  any other human: actionable — proceed to step 5, and send a
  notification as described in **Notifications**.
- CI changes: report new failures and newly passing checks. If a check
  fails, report it, send a notification, and offer to investigate; do not
  start fixing CI on your own.
- If a PR merged or closed, say so, send a notification, and stop
  monitoring that PR.

Mark items seen only after you have reported them or drafted a response
for them. Always give me the short per-tick status.

### 5. Act on actionable comments (draft only)

For each actionable comment:

1. Analyze what it asks for.
2. If a code change is needed, find a local checkout of that repository:
   use the session's directory when it is inside that repository,
   otherwise ask me where the checkout lives. Do not clone.
3. Before editing, make the checkout match the PR's current head.
   Re-fetch the PR first — the head may have moved since the last tick —
   and compare the local branch and HEAD commit against its `headRefName`
   and `headRefOid`. If the local checkout is not on the PR branch at its
   current head, fetch and check out the branch, preferably with
   `gh pr checkout <number>` (it handles fork heads). If the working tree
   is dirty, stop and ask me, offering exactly:
   - **No, cancel** — do nothing for this PR.
   - **Yes, stash the changes** — stash, switch, and tell me how to
     restore them afterwards.
   - **Yes, discard the changes** — warn me this is destructive: it
     discards uncommitted and untracked files.
   Do not choose on my behalf, and never discard anything unless I
   explicitly picked that option.
4. Make the change locally and run the repository's own fast checks
   (build, lint, unit tests) where they exist. Report failures.
5. Draft the reply: a direct answer for an inline review comment, or a
   comment for general discussion. Where a code change answers a comment,
   draft a short reply that points at the change.

### 6. Confirmation gate

Present, per PR: each new actionable comment (quoted or summarized), the
local diff or drafted reply that answers it, and check results. Send a
notification that drafts are ready, then ask me to confirm. Until I
confirm: no `git push`, no `gh pr comment`, no reply posting — nothing
public. After I confirm, publish exactly what I approved, then send a
notification stating what was published:

- Push the branch. A checkout made with `gh pr checkout` pushes to the
  PR's head branch by default.
- Post replies: `gh api repos/{owner}/{repo}/pulls/{number}/comments/{id}/replies -f body='...'`
  for inline review comments, `gh pr comment <url> --body '...'` for
  general comments.

If a push fails because I lack write access to the PR head, report it
instead of retrying. If I decline or adjust, redo the affected part and
ask again.

### 7. Ending

When the duration elapses or I ask you to stop, kill any background loop
you armed, send a final notification that monitoring has ended, confirm
the loop has stopped and why, and summarize the run: ticks executed,
comments addressed, replies and pushes published, and anything left
drafted but unconfirmed.
