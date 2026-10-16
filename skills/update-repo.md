# Update repo(s) from upstream — `/update-repo` command definition

This file is the single source of truth for the `/update-repo` command.
User-level command stubs in Claude Code (`~/.claude/commands/`), Cursor
(`~/.cursor/commands/`), and OpenCode (`~/.config/opencode/commands/`)
reference this file rather than duplicating it. The companion script is
`~/Projects/productivity-scripts/update-repo.sh`.

---

Update repositories by running the host shell alias `update <repo>` in each,
then checking out `main` in each. The helper script is context-aware: when
run inside a single repository it updates only that repository; when run
inside a dev-environments environment directory (such as
`ship-status-chai-release`) it updates all of that environment's composite
repositories.

Drive `~/Projects/productivity-scripts/update-repo.sh` with your shell tool,
from the session's current working directory, following these steps exactly:

1. Run `~/Projects/productivity-scripts/update-repo.sh check`. It prints the
   detected context (single repository or environment) and a `CLEAN`/`DIRTY`
   line per repository, including the uncommitted changes.
2. If any repository is reported `DIRTY`, stop and ask me how to proceed,
   offering exactly these options:
   - **No, cancel** — do not update anything; stop here.
   - **Yes, and leave the changes in place** — continue by running
     `~/Projects/productivity-scripts/update-repo.sh run --keep` (changes are
     stashed before updating and restored afterwards).
   - **Yes, but stash the changes** — continue by running
     `~/Projects/productivity-scripts/update-repo.sh run --stash` (changes
     stay stashed; tell me how to restore them).
   - **Yes, revert changes** — continue by running
     `~/Projects/productivity-scripts/update-repo.sh run --revert`. Warn me
     that this is destructive: it discards uncommitted and untracked files.

   Do not choose an option on my behalf, and never pass `--revert` unless I
   explicitly picked it.
3. If every repository is `CLEAN`, run
   `~/Projects/productivity-scripts/update-repo.sh run` with no flags.
4. After the script finishes, report what it did: the detected context, and
   for each repository whether uncommitted changes were kept, stashed (with
   restore instructions), or reverted, whether the upstream update succeeded,
   the final branch (expected `main`), and the working-tree state. Call out
   any failures explicitly and include the relevant error output.

This command is host-side only — the `update` alias comes from `~/.zshrc`
and does not exist inside devcontainers. If the script reports that no
context was found, tell me the session's directory must be a repository
under `~/Projects` or a dev-environments environment directory.
