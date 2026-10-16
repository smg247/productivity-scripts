#!/bin/bash
#
# Update a repository's main/master branch from its upstream remote, push it
# to origin, and return to the original branch.
#
# Usage: update-upstream.sh <repository>
#
# <repository> may be a path to a checkout, or a repository name, which is
# resolved under ${PROJECTS_DIR:-$HOME/Projects}. The host shell alias
# `update <repo>` (see ~/.zshrc) calls this script with a name.

set -e

repo="$1"
if [ -z "$repo" ]; then
  echo "usage: update-upstream.sh <repository-name-or-path>" >&2
  exit 2
fi
if [ ! -d "$repo" ]; then
  repo="${PROJECTS_DIR:-$HOME/Projects}/$repo"
fi
cd "$repo" 2>/dev/null || { echo "ERROR: no such repository: $1" >&2; exit 1; }

branch=$(git rev-parse --abbrev-ref HEAD)

if git show-ref --verify --quiet refs/heads/main; then
  master=main
elif git show-ref --verify --quiet refs/heads/master; then
  master=master
else
  echo "ERROR: no main or master branch in $repo" >&2
  exit 1
fi

echo "checking out $master in:"
pwd
git checkout "$master"

echo fetching upstream
git fetch upstream

echo merging upstream
git merge "upstream/$master"

echo pushing
git push origin "$master"

echo "checking out $branch"
git checkout "$branch"
