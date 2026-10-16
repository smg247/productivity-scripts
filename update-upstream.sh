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

master=$(git branch -l main master --format '%(refname:short)')

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
