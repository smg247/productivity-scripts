# Update repo(s) from upstream — `/update-repo` command definition

This file is the single source of truth for the `/update-repo` command.
User-level command stubs in Claude Code (`~/.claude/commands/`), Cursor
(`~/.cursor/commands/`), and OpenCode (`~/.config/opencode/commands/`)
reference this file rather than duplicating it. The companion script is
`~/Projects/productivity-scripts/update-repo.sh`.

---

Update repositories by running `update-upstream.sh` in each (it saves the
current branch, merges `main` from the upstream remote, pushes to `origin`,
and restores the original branch), then checking out `main` in each. The
helper script is context-aware: when run inside a single repository it
updates only that repository; when run inside a dev-environments
environment directory (such as `ship-status-chai-release`) it updates all
of that environment's composite repositories.

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
   the final branch, and the working-tree state. The final branch is
   expected to be `main`, except that with "leave the changes in place" a
   repository may remain on its original branch when the restored changes
   block switching to main — report that outcome as the script states it,
   not as a failure. Call out any failures explicitly and include the
   relevant error output.

This command works on the host and inside devcontainers (where the
repositories and `productivity-scripts` are mounted). Pushing to `origin`
requires git credentials available in the environment where it runs — if a
push or fetch fails with an authentication error, report that the
environment lacks credentials for the repository's remotes rather than
retrying. If the script reports that no context was found, tell me the
session's directory must be a repository or a dev-environments environment
directory.
