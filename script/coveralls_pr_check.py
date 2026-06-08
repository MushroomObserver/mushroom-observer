#!/usr/bin/env python3
"""Per-file coveralls coverage check for a PR.

Usage:
    script/coveralls_pr_check.py <PR_NUMBER>
    script/coveralls_pr_check.py <PR_NUMBER> --no-detail   # skip missed-line drill-down

What it does (for the given PR):
  1. Looks up the PR's coverage/coveralls check, extracts the build id
     from its targetUrl.
  2. Fetches every page of source_files.json from coveralls (Phlex
     views routinely land past page 1, so it paginates).
  3. Asks GitHub for the Ruby files changed in the PR (so the script
     works regardless of which branch is currently checked out).
  4. For each touched .rb file, prints covered/relevant/percent and,
     when coverage isn't 100%, fetches source.json for that file
     and lists the missed line numbers with the line text from the
     PR head commit (via `gh api`).

Output sections: "100% coverage", "Missed coverage" (with line
numbers + source), "Not instrumented" (expected for test files /
non-Ruby).

Requires: gh, curl, python3, git. No third-party libs.
"""

import argparse
import json
import subprocess
import sys
import urllib.parse
from pathlib import Path

COVERALLS_PER_PAGE = 2000
COVERALLS_MAX_PAGES = 10  # safety net


def sh(cmd, **kw):
    return subprocess.check_output(cmd, text=True, **kw).strip()


def curl_json(url):
    """GET a JSON URL via curl (system CA bundle, no Python SSL hassle)."""
    raw = subprocess.check_output(["curl", "-sSL", url], text=True)
    return json.loads(raw)


def get_build_id(pr_number):
    """Read the PR's coveralls check and pull the build id from its URL."""
    raw = sh(["gh", "pr", "checks", str(pr_number),
              "--json", "name,bucket,link"])
    checks = json.loads(raw)
    for c in checks:
        if "cover" in c.get("name", "").lower():
            link = c.get("link", "")
            # link looks like https://coveralls.io/builds/79886163
            tail = link.rsplit("/", 1)[-1]
            if tail.isdigit():
                return tail, c.get("bucket"), link
    raise SystemExit(f"No coveralls check found on PR #{pr_number}")


def fetch_source_files(build_id):
    """Paginate through source_files.json until a page returns 0."""
    all_files = []
    for page in range(1, COVERALLS_MAX_PAGES + 1):
        url = (f"https://coveralls.io/builds/{build_id}/source_files.json"
               f"?per_page={COVERALLS_PER_PAGE}&page={page}")
        d = curl_json(url)
        src = d["source_files"]
        if isinstance(src, str):
            src = json.loads(src)
        if not src:
            break
        all_files.extend(src)
    return all_files


def fetch_per_line(build_id, filename):
    """Return the per-line hit array for one source file.

    Format: a flat array with one entry per source line; None for
    non-executable lines, int hit count for executable lines (0 = missed).
    """
    encoded = urllib.parse.quote(filename, safe="")
    url = (f"https://coveralls.io/builds/{build_id}/source.json"
           f"?filename={encoded}")
    return curl_json(url)


def touched_ruby_files(pr_number):
    """List Ruby files added/modified in the PR, via GitHub API.

    Source of truth is the PR itself, not the local checkout — works
    even when a different branch is currently checked out.
    """
    raw = sh(["gh", "pr", "view", str(pr_number), "--json", "files"])
    files = json.loads(raw)["files"]
    out = []
    for f in files:
        if f.get("changeType") == "DELETED":
            continue
        path = f["path"]
        if path.endswith(".rb"):
            out.append(path)
    return sorted(out)


def get_pr_head_repo_and_sha(pr_number):
    """Repo + commit sha for the PR's head, used for fetching file contents."""
    raw = sh(["gh", "pr", "view", str(pr_number),
              "--json", "headRefOid,headRepository,headRepositoryOwner"])
    d = json.loads(raw)
    owner = d["headRepositoryOwner"]["login"]
    repo = d["headRepository"]["name"]
    return f"{owner}/{repo}", d["headRefOid"]


def read_file_lines(repo_slug, sha, path):
    """Read a file from the PR's head commit via gh api.

    Falls back to the local working tree if the API call fails (e.g.
    rate-limited, network down, deleted file). Returns None when
    nothing readable was found.
    """
    try:
        url = f"repos/{repo_slug}/contents/{path}?ref={sha}"
        raw = sh(["gh", "api", "-H", "Accept: application/vnd.github.raw",
                  url])
        return raw.splitlines()
    except subprocess.CalledProcessError:
        pass
    try:
        return Path(path).read_text().splitlines()
    except OSError:
        return None


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("pr_number")
    p.add_argument("--no-detail", action="store_true",
                   help="Skip per-line drill-down for missed coverage")
    args = p.parse_args()

    build_id, bucket, link = get_build_id(args.pr_number)
    print(f"PR #{args.pr_number}  build {build_id}  status={bucket}  {link}")
    print()

    src_files = fetch_source_files(build_id)
    by_name = {f["name"]: f for f in src_files}
    print(f"Fetched {len(src_files)} instrumented files from coveralls.")

    paths = touched_ruby_files(args.pr_number)
    print(f"Touched .rb files in PR (via gh): {len(paths)}")

    repo_slug, head_sha = (None, None)
    if not args.no_detail:
        repo_slug, head_sha = get_pr_head_repo_and_sha(args.pr_number)
    print()

    ok, missed, ni = [], [], []
    for path in paths:
        f = by_name.get(path)
        if not f:
            ni.append(path)
            continue
        rel = f["relevant_line_count"]
        cov = f["covered_line_count"]
        miss = f["missed_line_count"]
        pct = 100.0 * cov / rel if rel else 100.0
        line = f"{path}: {cov}/{rel} ({pct:.1f}%)"
        if miss == 0:
            ok.append(line)
        else:
            missed.append((path, line, miss))

    print(f"=== 100% coverage ({len(ok)} files) ===")
    for line in ok:
        print(f"  OK    {line}")
    print()

    print(f"=== Missed coverage ({len(missed)} files) ===")
    for path, line, miss in missed:
        print(f"  MISS  {line}  -- {miss} missed")
        if args.no_detail:
            continue
        try:
            per_line = fetch_per_line(build_id, path)
        except Exception as e:
            print(f"        (per-line fetch failed: {e})")
            continue
        src_lines = read_file_lines(repo_slug, head_sha, path)
        for i, hit in enumerate(per_line):
            if hit != 0:
                continue
            lineno = i + 1
            src = (src_lines[i] if src_lines and i < len(src_lines)
                   else "<source unavailable>")
            print(f"        L{lineno:>4}: {src.rstrip()}")
    print()

    print(f"=== Not instrumented ({len(ni)} files) ===")
    for path in ni:
        print(f"  --    {path}")
    print()

    print(f"SUMMARY: {len(ok)} clean, {len(missed)} missed, "
          f"{len(ni)} not instrumented")
    return 0 if not missed else 1


if __name__ == "__main__":
    sys.exit(main())
