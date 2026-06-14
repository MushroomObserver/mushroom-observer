#!/usr/bin/env bash
# Claude Code PostToolUse hook.
# Fires after a successful `Bash` call. If the command was a `git push`
# and the current branch has an open PR with at least one coveralls
# report, prints per-file coverage for every Ruby file in the diff
# and flags any file below 100%.
#
# Non-blocking. The goal is to make coverage gaps impossible to miss
# after every push, not to gate the push itself.
#
# Reads JSON on stdin from Claude Code; only inspects `tool_input.command`.
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Only interested in git push. Skip everything else.
case "$COMMAND" in
  *"git push"*) ;;
  *) exit 0 ;;
esac

PR_NUM="$(gh pr view --json number --jq .number 2>/dev/null || true)"
if [ -z "$PR_NUM" ]; then
  # No PR for this branch yet (initial push that will create the PR,
  # or a branch that isn't headed for review). Nothing to check.
  exit 0
fi

BUILD_ID="$(gh pr view "$PR_NUM" --json comments \
  --jq '.comments[] | select(.author.login=="coveralls-official") | .body' 2>/dev/null |
  grep -oE "coveralls.io/builds/[0-9]+" | tail -1 | grep -oE "[0-9]+$" || true)"

if [ -z "$BUILD_ID" ]; then
  echo "" >&2
  echo "📊 PR #${PR_NUM}: coveralls hasn't reported on a build yet — re-run this check after CI finishes (~10–15 min)." >&2
  exit 0
fi

# Paginate source_files.json. Phlex views consistently land on page 2;
# a single-page fetch reports them as <not instrumented> (false negative).
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

page=1
while : ; do
  curl -sf "https://coveralls.io/builds/${BUILD_ID}/source_files.json?per_page=2000&page=${page}" \
    > "${TMPDIR}/page_${page}.json" || break
  count=$(ruby -rjson -e "
    d = JSON.parse(File.read('${TMPDIR}/page_${page}.json'))
    src = d['source_files']
    src = JSON.parse(src) if src.is_a?(String)
    print src.length
  " 2>/dev/null || echo 0)
  [ "$count" = "0" ] && break
  page=$((page + 1))
  [ "$page" -gt 10 ] && break
done

gh pr view "$PR_NUM" --json files \
  --jq '.files[] | select(.changeType!="DELETED") | .path' |
  grep -E '\.rb$' > "${TMPDIR}/touched.txt" || true

if [ ! -s "${TMPDIR}/touched.txt" ]; then
  exit 0
fi

REPORT="$(TMPDIR="$TMPDIR" ruby -rjson -e '
  tmp = ENV.fetch("TMPDIR")
  files = Dir[File.join(tmp, "page_*.json")].sort.flat_map do |path|
    d = JSON.parse(File.read(path))
    src = d["source_files"]
    src = JSON.parse(src) if src.is_a?(String)
    src
  end
  by_name = files.each_with_object({}) { |x, h| h[x["name"]] = x }
  paths = File.readlines(File.join(tmp, "touched.txt"))
                .map(&:strip).reject(&:empty?)
  gaps = paths.filter_map do |p|
    f = by_name[p]
    next unless f && f["missed_line_count"] > 0
    cov, rel, miss = f["covered_line_count"], f["relevant_line_count"], f["missed_line_count"]
    pct = rel > 0 ? (100.0 * cov / rel) : 0
    format("%s: %d/%d (%.1f%%)  MISSED %d", p, cov, rel, pct, miss)
  end
  print gaps.join("\n")
')"

if [ -n "$REPORT" ]; then
  cat >&2 <<EOF

📊 PR #${PR_NUM} — coveralls per-file coverage gaps on touched files (build ${BUILD_ID}):

${REPORT}

Per the project's testing rules: every Ruby file in a PR must be at
100% line coverage before declaring done. Fix gaps in the same PR.
EOF
else
  echo "" >&2
  echo "✅ PR #${PR_NUM}: every touched Ruby file at 100% coverage (build ${BUILD_ID})." >&2
fi

exit 0
