#!/usr/bin/env bash
# Claude Code PreToolUse hook.
# Fires before `Bash` calls. Blocks `gh` commands that would PUBLISH
# content to (public) GitHub -- issue/PR create|edit|comment|review and
# `gh api` calls that set a `body=` field -- when the content contains a
# real email address.
#
# Why: an email in a GitHub issue/PR/comment is PII posted publicly. On a
# public repo it is broadcast verbatim to the events firehose (GH Archive,
# bots) at creation time, and editing afterward does NOT remove it (edit
# history is retained). So it has to be stopped BEFORE it is sent. See
# .claude/rules/no_pii_in_public.md.
#
# Scope: scans the command string itself (inline `--body`/`-b`/`-f body=`)
# AND the contents of any `--body-file` (the mandated form for PR
# bodies -- see .claude/rules/gh_pr_bodies.md), which is where the real
# leak hid in the incident that prompted this hook.
#
# Blunt by design: for outbound-to-public commands, err toward blocking.
# Known non-PII addresses (noreply, git@github.com) are allowlisted so
# Co-Authored-By trailers and SSH-style refs don't trip it.
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Gate: only inspect gh commands that publish content.
if ! printf '%s' "$COMMAND" | grep -qE \
  'gh[[:space:]]+(issue|pr)[[:space:]]+(create|edit|comment|review)|gh[[:space:]]+api[[:space:]].*body='; then
  exit 0
fi

EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

# Gather candidate emails from the command string and any --body-file(s).
CANDIDATES="$(printf '%s' "$COMMAND" | grep -oE "$EMAIL_RE" || true)"
FILES="$(printf '%s' "$COMMAND" \
  | grep -oE -- '--body-file[[:space:]=]+[^[:space:]]+' \
  | sed -E 's/^--body-file[[:space:]=]+//' | tr -d "\"'" || true)"
for f in $FILES; do
  [ -f "$f" ] && CANDIDATES="$CANDIDATES
$(grep -oE "$EMAIL_RE" "$f" || true)"
done

# Drop well-known non-PII addresses (noreply, github noreply, git@github.com).
REAL="$(printf '%s' "$CANDIDATES" | grep -vE \
  '(^|[^A-Za-z0-9._%+-])(no-?reply@|git@github\.com)|\.noreply\.github\.com' \
  | grep -E "$EMAIL_RE" || true)"

if [ -n "$REAL" ]; then
  cat >&2 <<'EOF'
🚫 BLOCKED: this GitHub publish command contains an email address.

Email addresses are PII and must never be posted to GitHub issues,
PRs, or comments. On a public repo the content is broadcast to the
events firehose (GH Archive / bots) the moment it is created, and
editing later does NOT remove it -- so it has to be stopped now.

Fix: remove the email from the body. Refer to the person by their
internal id or public handle, and write "contact details on file
(not reproduced here)" instead of the address. Then retry.

If this is a false positive (a non-PII address that must appear),
ask the user to confirm before posting.

See .claude/rules/no_pii_in_public.md.
EOF
  exit 2
fi

exit 0
