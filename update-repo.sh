#!/bin/bash
#
# update-repo.sh — context-aware frontend to update-upstream.sh, which
# merges a repository's main/master branch from its upstream remote, pushes
# it to origin, and restores the original branch. update-upstream.sh is
# invoked directly (not through the `update` shell alias), so this works
# both on the host and inside devcontainers where the repositories are
# mounted.
#
# Context detection is based on the current working directory:
#
#   * inside a git repository: update only that repository;
#   * inside a development-environment directory (the current directory or
#     an ancestor containing .devcontainer/devcontainer.json, including the
#     container layout <workspace>/.dev-environment): update every
#     composite repository bind-mounted by that environment, discovered
#     from its devcontainer.json (writable sibling bind mounts). Each
#     repository resolves to its host checkout or its in-container mount
#     target, whichever exists.
#
# For each targeted repository the script:
#
#   1. runs update-upstream.sh, which saves the current branch, checks out
#      main, merges from the upstream remote, pushes to origin, and returns
#      to the original branch;
#   2. checks out main.
#
# Uncommitted changes (including untracked files) are detected before
# anything runs. Interactive use prompts for a decision; non-interactive
# callers must pass --keep, --stash, or --revert. Run `check` first to see
# the detected context and which repositories are dirty.
#
#   --keep    stash uncommitted changes and restore them (stash pop) right
#             after the update, leaving them in the working tree
#   --stash   stash uncommitted changes and leave them stashed afterwards
#   --revert  discard uncommitted changes (git reset --hard + git clean -fd)
#
# Pushing to origin requires git credentials available in the environment
# where this script runs (inside devcontainers, SSH remotes need keys the
# container can access).
#
# Usage:
#   update-repo.sh check                       report context and tree state
#   update-repo.sh run [--keep|--stash|--revert]
#   update-repo.sh [--keep|--stash|--revert]   same as run
#
# Exit codes:
#   0   success
#   1   failure (no context found, unusable repository, or a failed step)
#   2   usage error
#   10  uncommitted changes need a stash/revert decision

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION=""
MODE=""
TARGETS=""       # newline-separated "name<TAB>directory" entries
TARGET_LABEL=""

usage() {
  cat <<'EOF'
Usage: update-repo.sh check
       update-repo.sh run [--keep|--stash|--revert]
       update-repo.sh [--keep|--stash|--revert]
EOF
}

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

# --- context detection -----------------------------------------------------

detect_context() {
  local dir="$PWD" root
  while :; do
    if [ -e "$dir/.git" ]; then
      MODE=repo
      root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$dir")"
      resolve_single_repo "$root"
      return 0
    fi
    if [ -f "$dir/.devcontainer/devcontainer.json" ]; then
      MODE=env
      resolve_environment "$dir"
      return 0
    fi
    if [ -f "$dir/.dev-environment/.devcontainer/devcontainer.json" ]; then
      # container layout: the environment folder is mounted inside the
      # container workspace
      MODE=env
      resolve_environment "$dir/.dev-environment"
      return 0
    fi
    if [ "$dir" = "/" ]; then
      return 1
    fi
    dir="$(dirname "$dir")"
  done
}

resolve_single_repo() {
  local root="$1"
  local name
  name="$(basename "$root")"
  TARGETS="$(printf '%s\t%s\n' "$name" "$root")"
  TARGET_LABEL="repository $name"
}

resolve_environment() {
  local env_dir="$1"
  local dc base match src tgt name dir
  dc="$env_dir/.devcontainer/devcontainer.json"
  base="$(cd "$env_dir/../.." 2>/dev/null && pwd -P)" || fail "cannot resolve the repository base directory for $env_dir."
  TARGETS=""
  while IFS= read -r match; do
    [ -z "$match" ] && continue
    case "$match" in
      *readonly*) continue ;;   # read-only mounts are tooling, not composite repos
    esac
    src="${match#source=}"
    src="${src%%,*}"
    tgt="${match#*,target=}"
    tgt="${tgt%%,*}"
    name="${tgt#/workspace/}"
    case "$name" in
      */*|"") continue ;;
    esac
    if [ "$src" = "\${localWorkspaceFolder}/../../$name" ]; then
      # resolve to the host checkout (sibling of the environment's parent)
      # or to the in-container mount target, whichever is a git repository
      dir=""
      if git -C "$base/$name" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        dir="$base/$name"
      elif git -C "$tgt" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        dir="$tgt"
      else
        dir="$base/$name"   # validate_targets reports a clear error
      fi
      TARGETS="$TARGETS$name$TAB$dir
"
    fi
  done <<EOF
$(grep -o 'source=[^"]*' "$dc")
EOF
  if [ -z "$TARGETS" ]; then
    fail "no composite repositories found in $dc."
  fi
  local label
  label="$(basename "$env_dir")"
  if [ "$label" = ".dev-environment" ]; then
    label="container workspace"
  fi
  TARGET_LABEL="environment $label ($(printf '%s\n' "$TARGETS" | cut -f1 | tr '\n' ' ' | sed 's/ *$//'))"
}

validate_targets() {
  local name dir
  while IFS="$TAB" read -r name dir; do
    [ -z "$name" ] && continue
    if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      fail "$dir is not a git repository."
    fi
    if [ -z "$(git -C "$dir" config remote.upstream.url)" ]; then
      fail "$name has no 'upstream' remote, which update-upstream.sh requires."
    fi
  done <<EOF
$TARGETS
EOF
}

# --- per-repository helpers -------------------------------------------------

is_dirty() {
  [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]
}

describe_dirty() {
  local name dir
  while IFS="$TAB" read -r name dir; do
    [ -z "$name" ] && continue
    if is_dirty "$dir"; then
      echo "  $name:"
      git -C "$dir" status --porcelain | sed 's/^/    /'
    fi
  done <<EOF
$TARGETS
EOF
}

cmd_check() {
  local name dir dirty=0
  echo "context: $TARGET_LABEL"
  while IFS="$TAB" read -r name dir; do
    [ -z "$name" ] && continue
    if is_dirty "$dir"; then
      echo "DIRTY $name"
      git -C "$dir" status --porcelain | sed 's/^/    /'
      dirty=1
    else
      echo "CLEAN $name"
    fi
  done <<EOF
$TARGETS
EOF
  if [ "$dirty" -eq 1 ]; then
    echo
    echo "Uncommitted changes detected. Decide how to handle them, then run"
    echo "with --keep, --stash, or --revert."
    return 10
  fi
  return 0
}

prompt_for_action() {
  echo "Uncommitted changes:"
  describe_dirty
  cat <<'EOF'

Proceed with the update?
  1) No, cancel
  2) Yes, and leave the changes in place (stash now, restore after updating)
  3) Yes, but stash the changes (leave them stashed afterwards)
  4) Yes, revert changes (destructive: discards uncommitted and untracked files)
EOF
  local choice
  while true; do
    printf 'Choice [1-4]: '
    IFS= read -r choice || exit 0
    case "$choice" in
      1) echo "Cancelled."; exit 0 ;;
      2) ACTION=keep; return 0 ;;
      3) ACTION=stash; return 0 ;;
      4) ACTION=revert; return 0 ;;
      *) echo "Please enter 1, 2, 3, or 4." ;;
    esac
  done
}

cmd_run() {
  local name dir handled handled_short update_ok checkout_ok branch tree stashed
  local failures=0 need_decision=0 summary="" left_on_branch=0

  while IFS="$TAB" read -r name dir; do
    [ -z "$name" ] && continue
    is_dirty "$dir" && need_decision=1
  done <<EOF
$TARGETS
EOF

  if [ "$need_decision" -eq 1 ] && [ -z "$ACTION" ]; then
    if [ -t 0 ]; then
      prompt_for_action
    else
      echo "ERROR: uncommitted changes detected, and neither --keep, --stash, nor --revert was given." >&2
      echo >&2
      describe_dirty >&2
      echo >&2
      echo "Decide how to handle them, then re-run with --keep, --stash, or --revert." >&2
      exit 10
    fi
  fi

  echo "context: $TARGET_LABEL"

  while IFS="$TAB" read -r name dir; do
    [ -z "$name" ] && continue
    echo "=== $name ==="

    handled_short="clean"
    handled="working tree was clean"
    stashed=no
    if is_dirty "$dir"; then
      case "$ACTION" in
        keep|stash)
          if git -C "$dir" stash push -u -m "update-repo $(date +%Y-%m-%d-%H%M%S)" >/dev/null; then
            stashed=yes
            if [ "$ACTION" = "keep" ]; then
              handled_short="kept"
              handled="stashed uncommitted changes; they will be restored after the update"
            else
              handled_short="stashed"
              handled="stashed uncommitted changes (restore with: git -C $dir stash list / git -C $dir stash pop)"
            fi
          else
            handled_short="STASH FAILED"
            handled="failed to stash uncommitted changes"
            failures=1
          fi
          ;;
        revert)
          if git -C "$dir" reset --hard HEAD >/dev/null 2>&1 && git -C "$dir" clean -fd >/dev/null; then
            handled_short="reverted"
            handled="reverted (discarded) uncommitted changes"
          else
            handled_short="REVERT FAILED"
            handled="failed to revert uncommitted changes"
            failures=1
          fi
          ;;
        *)
          handled_short="left dirty"
          handled="left uncommitted changes in place"
          ;;
      esac
    fi
    echo "$handled"

    echo "running update-upstream.sh in $name (checkout main, merge upstream, push origin, restore branch)..."
    update_ok=yes
    "$SCRIPT_DIR/update-upstream.sh" "$dir" || { update_ok=no; failures=1; }
    echo "update: $update_ok"

    if [ "$stashed" = "yes" ] && [ "$ACTION" = "keep" ]; then
      if git -C "$dir" stash pop; then
        echo "restored stashed changes"
      else
        handled_short="RESTORE FAILED"
        handled="failed to restore stashed changes; the stash is intact (resolve manually with: git -C $dir stash pop)"
        failures=1
        stashed=failed
      fi
    fi

    if [ "$stashed" = "failed" ]; then
      checkout_ok=skipped
    else
      checkout_ok=yes
      if ! git -C "$dir" checkout main >/dev/null 2>&1; then
        if [ "$ACTION" = "keep" ]; then
          # expected --keep outcome: the restored changes belong to the
          # original branch and block switching to main; leave them there
          checkout_ok="left on branch"
          left_on_branch=$((left_on_branch + 1))
        else
          checkout_ok=no
          failures=1
        fi
      fi
    fi
    branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
    if is_dirty "$dir"; then tree="dirty"; else tree="clean"; fi
    echo "branch: ${branch:-unknown} (checkout main: $checkout_ok), working tree: $tree"
    echo

    summary="$summary  $name: $handled_short; update $update_ok; on ${branch:-unknown}; tree $tree
"
  done <<EOF
$TARGETS
EOF

  echo "================ summary ================"
  printf '%s' "$summary"
  if [ "$failures" -eq 0 ]; then
    if [ "$left_on_branch" -gt 0 ]; then
      echo "Done: every targeted repository updated. Repositories whose restored"
      echo "changes block switching to main remain on their original branch."
    else
      echo "Done: every targeted repository updated and checked out on main."
    fi
  else
    echo >&2
    echo "WARNING: some steps failed; review the output above." >&2
  fi
  exit "$failures"
}

# --- entry point -------------------------------------------------------------

TAB="$(printf '\t')"

MODE_CLI=run
case "${1:-}" in
  check) MODE_CLI=check; shift ;;
  run) MODE_CLI=run; shift ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --keep|--stash|--revert)
      if [ -n "$ACTION" ]; then usage >&2; exit 2; fi
      ACTION="${1#--}"
      ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

if ! detect_context; then
  fail "not inside a git repository or a development-environment directory (no .devcontainer/devcontainer.json found in any ancestor of $PWD)."
fi
validate_targets

case "$MODE_CLI" in
  check) cmd_check; exit $? ;;
  run) cmd_run ;;
esac
