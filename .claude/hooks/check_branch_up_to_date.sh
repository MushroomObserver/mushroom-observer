#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before Bash calls. If the command is a `git push` or
# `gh pr create`, verifies the current branch has incorporated all
# commits from origin/main. Exits 2 (blocking) if the branch is behind.
#
# Skips when already on main/master.
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

case "$COMMAND" in
  *"git push"*|*"gh pr create"*) ;;
  *) exit 0 ;;
esac

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
[ -z "$BRANCH" ] && exit 0
[ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ] && exit 0

# Fetch quietly so the check reflects current remote state.
git fetch origin main --quiet 2>/dev/null || true

# If origin/main is not an ancestor of HEAD, we're behind main.
if ! git merge-base --is-ancestor origin/main HEAD 2>/dev/null; then
  BEHIND="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "?")"
  cat >&2 <<EOF
🚫 Branch '$BRANCH' is behind origin/main by ${BEHIND} commit(s) — blocking push/PR.

Merge main before pushing:
  git fetch origin main
  git merge origin/main

Resolve any conflicts, commit, then try again.
EOF
  exit 2
fi

exit 0
