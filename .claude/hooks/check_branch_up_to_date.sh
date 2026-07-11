#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before Bash calls. If the command is a `git push` or
# `gh pr create`, verifies the current branch has incorporated all
# commits from origin/main. Exits 2 (blocking) if the branch is behind.
#
# PreToolUse hooks block the ENTIRE Bash call, not just the risky
# part - so a compound command like `git commit -m "..." && git push`
# would otherwise lose the commit too when only the push should be
# blocked. To avoid that, when blocking we first run whatever precedes
# the `git push`/`gh pr create` invocation (split on the first literal
# occurrence of either) as its own step, so a bundled commit still
# lands. This is a plain substring split, not real shell parsing - it
# can misfire if "git push"/"gh pr create" appears as literal text
# earlier in the command (e.g. inside a commit message body); in that
# case the extracted prefix will typically just fail safely (e.g. an
# unterminated heredoc) rather than doing anything silently wrong.
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

  # Split on whichever of the two risky invocations occurs first.
  PREFIX_PUSH="${COMMAND%%git push*}"
  PREFIX_GHPR="${COMMAND%%gh pr create*}"
  if [ "$PREFIX_PUSH" != "$COMMAND" ] && [ "$PREFIX_GHPR" != "$COMMAND" ]; then
    if [ "${#PREFIX_PUSH}" -le "${#PREFIX_GHPR}" ]; then
      PREFIX="$PREFIX_PUSH"
    else
      PREFIX="$PREFIX_GHPR"
    fi
  elif [ "$PREFIX_PUSH" != "$COMMAND" ]; then
    PREFIX="$PREFIX_PUSH"
  else
    PREFIX="$PREFIX_GHPR"
  fi
  # Trim a trailing statement separator and whitespace left dangling
  # by the split (e.g. "git commit -m 'x' && " -> "git commit -m 'x'").
  PREFIX="$(printf '%s' "$PREFIX" | sed -E 's/[[:space:]]*(&&|\|\||;)[[:space:]]*$//')"

  RAN_MSG="(nothing preceded the push/PR-create step)"
  if [ -n "$(printf '%s' "$PREFIX" | tr -d '[:space:]')" ]; then
    echo "▶ Running the portion of the command before push/PR-create:" >&2
    printf '%s\n' "$PREFIX" >&2
    if bash -c "$PREFIX" >&2 2>&1; then
      RAN_MSG="✅ that portion ran successfully - only the push/PR-create below was blocked."
    else
      RAN_MSG="⚠️  that portion FAILED (see output above) - nothing further ran, including the push/PR-create."
    fi
  fi

  cat >&2 <<EOF

🚫 Branch '$BRANCH' is behind origin/main by ${BEHIND} commit(s) — blocking push/PR.

$RAN_MSG

Merge main before pushing:
  git fetch origin main
  git merge origin/main

Resolve any conflicts, commit, then try again.
EOF
  exit 2
fi

exit 0
