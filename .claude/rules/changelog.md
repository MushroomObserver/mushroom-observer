# Changelog block — required in every PR description

Every `gh pr create` body must include a changelog block (put it at the
end, after the test plan):

```
<!-- changelog -->
article: yes
Maps of name lists now support clustering and zoom.
<!-- /changelog -->
```

This is the PR-time half of the automated changelog (issue #5155).
Two changelogs are generated from merged PRs at deploy time:

- **`CHANGELOG.md`** — technical, lists every merged PR. Nothing to do
  per-PR; the generator uses the PR title.
- **The MO Article changelog** (user-facing, curated) — fed by this
  block: `article:` decides whether the PR appears there, and the
  sentence is what site users read.

Reviewers edit the block in place like any other part of the PR body.
A PR with no block is excluded from the Article and flagged in the
deploy output for manual review — the block is how a deliberate
decision is told apart from an omission.

## Filling it in

**`article: yes`** for changes a non-technical site user would notice
or care about: new features, UI changes, user-visible bug fixes,
performance improvements users would feel.

**`article: no`** for internal work: refactors, tests, CI/tooling,
code style, RuboCop cops, dependency bumps, dev docs, admin-only
tooling, data repairs with no visible effect. Omit the sentence line.

When genuinely unsure, prefer `yes` — a reviewer can flip it to `no`
faster than they can notice an omission.

**The sentence** (required when `article: yes`, one line):

- Written for mushroom observers, not developers. Describe what
  changed from the user's point of view, not how: "Emoji now work in
  comments and profile notes," not "Convert `comments.comment` to
  utf8mb4."
- No code identifiers, no backticks, no class/method/file names.
- No PR/issue numbers — the generator adds the links.
- Plain present tense, capitalized, ending punctuation optional.

## Format is machine-parsed — keep it exact

The generator reads everything between `<!-- changelog -->` and
`<!-- /changelog -->`: the first non-blank line must be
`article: yes` or `article: no`; the remaining non-blank lines are the
sentence. A block that does not parse is treated as absent (excluded
from the Article, flagged at deploy).
