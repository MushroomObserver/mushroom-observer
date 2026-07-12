# No PII in GitHub issues, PRs, or any public artifact

**Never** put personally identifiable information — email addresses, phone numbers, physical/mailing addresses, or other private personal data — into a GitHub issue, pull request, comment, review, or any other publicly shared artifact. This is a hard rule.

## Why this is not fixable after the fact

Editing the issue/PR to remove the PII is **not enough**:

- GitHub retains full **edit history** on issue and PR bodies. Anyone with read access (and crawlers) can view every prior revision via the "edited" dropdown. The PII stays recoverable.
- On a **public** repo, creating an issue/PR/comment emits a public event to GitHub's events firehose the moment it is posted. That firehose is archived permanently (GH Archive) and consumed by bots and research crawlers in real time. Deleting the content later does **not** reach anything that already ingested it.

So PII has to be stopped **before** it is posted. If it does leak, a plain edit is insufficient — the edit history keeps every prior revision. For an **issue**, delete it entirely (`gh issue delete <n> --yes`); that removes the issue and its history from GitHub. Then recreate a sanitized version. A **PR cannot be deleted** this way — `gh pr close` only closes it, leaving the body and edit history intact — so scrubbing a leaked PR body needs a repo admin (or GitHub Support). Either route still **cannot** retract anything the firehose already captured.

## What to write instead

- Refer to a person only by their **internal id** (e.g. "user 8504") or their **public handle/login**.
- Instead of pasting an email or other contact info, write **"contact details on file (recoverable from backups; not reproduced here)."**
- Public MO data is fine — observation locations, a public login or display name. The **private account fields are not**: email, password, mailing address, phone.

## Enforcement

This is enforced by a `PreToolUse` hook, `.claude/hooks/block_pii_in_gh.sh`, wired into `.claude/settings.json`. It blocks two things when an email-shaped string appears (allowlisting `noreply@…` and `git@github.com`): a `gh issue`/`gh pr` create/edit/comment/review whose inline body **or `--body-file`** contents contain one, and a `gh api` call that sets a `body=` field inline. If it fires, remove the address and retry; if it is a genuine false positive, confirm with the user before posting.

The hook is a backstop, not a substitute for judgment — the primary rule is simply: don't write PII into anything that goes to GitHub.
