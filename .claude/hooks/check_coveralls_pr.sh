#!/usr/bin/env bash
# Claude Code PostToolUse hook.
# Fires after a successful `Bash` call. If the command was a `git push`
# and the current branch has an open PR with at least one coveralls
# report, prints two reports:
#
#   1. Per-file coverage for every Ruby file in the diff; flags any
#      below 100% (the "touched files" report — gaps the PR has to
#      fix in scope).
#   2. Untouched Ruby files whose coverage dropped vs the base build
#      (the "ripple" report — typically a helper that lost callers
#      when the PR replaced an ERB with a Phlex component).
#
# Non-blocking. The goal is to make coverage drops impossible to miss
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

fetch_source_files() {
  local build_id="$1" prefix="$2" page=1 count
  while : ; do
    curl -sf "https://coveralls.io/builds/${build_id}/source_files.json?per_page=2000&page=${page}" \
      > "${TMPDIR}/${prefix}_${page}.json" || return 1
    count=$(ruby -rjson -e "
      d = JSON.parse(File.read('${TMPDIR}/${prefix}_${page}.json'))
      src = d['source_files']
      src = JSON.parse(src) if src.is_a?(String)
      print src.length
    " 2>/dev/null || echo 0)
    [ "$count" = "0" ] && break
    page=$((page + 1))
    [ "$page" -gt 10 ] && break
  done
}

if ! fetch_source_files "$BUILD_ID" pr; then
  echo "" >&2
  echo "📊 PR #${PR_NUM}: couldn't fetch coveralls source_files.json for build ${BUILD_ID} (transient network/API error)." >&2
  exit 0
fi

gh pr view "$PR_NUM" --json files \
  --jq '.files[] | select(.changeType!="DELETED") | .path' |
  grep -E '\.rb$' > "${TMPDIR}/touched.txt" || true

if [ ! -s "${TMPDIR}/touched.txt" ]; then
  exit 0
fi

# Find the base build for delta computation. Coveralls' per-file
# `coverage_change` isn't in the public JSON, so we fetch
# `origin/main`'s build separately and compute deltas in-process.
# Falls back to skipping the ripple report when:
#   - there's no `origin/main` fetched locally (rare on dev machines), or
#   - coveralls has no build for that SHA yet (CI hasn't reported on
#     the current main tip — also rare; main runs CI on every merge).
MAIN_BUILD_ID=""
if MAIN_SHA="$(git rev-parse --verify origin/main 2>/dev/null)"; then
  MAIN_BUILD_ID="$(curl -sf "https://coveralls.io/builds/${MAIN_SHA}.json" 2>/dev/null |
    ruby -rjson -e 'print JSON.parse(STDIN.read)["id"] rescue ""' || true)"
fi

if [ -n "$MAIN_BUILD_ID" ]; then
  # Pagination failure on the main fetch isn't fatal — the touched-files
  # report doesn't need it. Drop the partial data and skip ripple instead.
  fetch_source_files "$MAIN_BUILD_ID" main || {
    rm -f "${TMPDIR}"/main_*.json
    MAIN_BUILD_ID=""
  }
fi

TMPDIR="$TMPDIR" ruby -rjson -rset -e '
  tmp = ENV.fetch("TMPDIR")
  def load(tmp, prefix)
    Dir[File.join(tmp, "#{prefix}_*.json")].sort.flat_map do |path|
      d = JSON.parse(File.read(path))
      src = d["source_files"]
      src = JSON.parse(src) if src.is_a?(String)
      src
    end
  end
  def pct(f)
    rel = f["relevant_line_count"].to_i
    rel > 0 ? (100.0 * f["covered_line_count"].to_i / rel) : 0.0
  end

  pr_files = load(tmp, "pr")
  main_files = load(tmp, "main")
  pr_by_name = pr_files.each_with_object({}) { |x, h| h[x["name"]] = x }
  main_by_name = main_files.each_with_object({}) { |x, h| h[x["name"]] = x }
  touched = File.readlines(File.join(tmp, "touched.txt"))
                .map(&:strip).reject(&:empty?)
  touched_set = touched.to_set

  File.open(File.join(tmp, "touched_report.txt"), "w") do |io|
    touched.each do |p|
      f = pr_by_name[p]
      next unless f && f["missed_line_count"].to_i > 0
      cov  = f["covered_line_count"].to_i
      rel  = f["relevant_line_count"].to_i
      miss = f["missed_line_count"].to_i
      io.puts(format("%s: %d/%d (%.1f%%)  MISSED %d", p, cov, rel, pct(f), miss))
    end
  end

  ripple = []
  unless main_files.empty?
    pr_files.each do |pr_f|
      name = pr_f["name"].to_s
      next unless name.end_with?(".rb")
      next if touched_set.include?(name)
      main_f = main_by_name[name]
      next unless main_f
      delta = pct(pr_f) - pct(main_f)
      next if delta >= -0.01
      ripple << [pr_f, main_f, delta]
    end
  end

  File.open(File.join(tmp, "ripple_report.txt"), "w") do |io|
    ripple.sort_by { |_, _, d| d }.each do |pr_f, main_f, delta|
      cov  = pr_f["covered_line_count"].to_i
      rel  = pr_f["relevant_line_count"].to_i
      miss = pr_f["missed_line_count"].to_i
      io.puts(format("%s: %d/%d (%.1f%%, %+.1fpp vs main)  MISSED %d",
                     pr_f["name"], cov, rel, pct(pr_f), delta, miss))
    end
  end
' 2>/dev/null

TOUCHED_REPORT="$(cat "${TMPDIR}/touched_report.txt" 2>/dev/null || true)"
RIPPLE_REPORT="$(cat "${TMPDIR}/ripple_report.txt" 2>/dev/null || true)"

if [ -n "$TOUCHED_REPORT" ]; then
  cat >&2 <<EOF

📊 PR #${PR_NUM} — coveralls per-file coverage gaps on touched files (build ${BUILD_ID}):

${TOUCHED_REPORT}

Per the project's testing rules: every Ruby file in a PR must be at
100% line coverage before declaring done. Fix gaps in the same PR.
EOF
else
  echo "" >&2
  echo "✅ PR #${PR_NUM}: every touched Ruby file at 100% coverage (build ${BUILD_ID})." >&2
fi

if [ -n "$RIPPLE_REPORT" ]; then
  cat >&2 <<EOF

📉 PR #${PR_NUM} — untouched Ruby files whose coverage DROPPED vs main
(PR build ${BUILD_ID} vs main build ${MAIN_BUILD_ID}):

${RIPPLE_REPORT}

Untouched files don't usually move. Common cause: a helper / partial
the PR stopped calling now has fewer (or zero) callers exercising it
in the test suite. If the file is dead, delete it; if it's still
in use elsewhere, the test that covered the now-removed call site
needs a replacement.
EOF
fi

exit 0
