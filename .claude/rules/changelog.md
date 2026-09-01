# Changelog block — required in every PR description

Every `gh pr create` body must include a changelog block (put it at the
end, after the test plan):

```
<!-- changelog -->
article: yes
Add clustering and zoom to name list maps
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

- **Short: 60 characters or fewer.** It becomes one table cell in the
  Article, and longer text wraps the table. Readers who want detail
  click through to the PR, so the sentence only has to say *what*
  changed, not every case it covers: "Link field slip scans from
  observation and image pages," not "Field slip scans are now
  reachable from the observation page, and a photo's existing scan
  result is linked from its image page instead of only offering a
  re-read."
- Written for mushroom observers, not developers. Describe what
  changed from the user's point of view, not how: "Emoji now work in
  comments and profile notes," not "Convert `comments.comment` to
  utf8mb4."
- Terse, like the existing Article rows: lead with the verb — "Fix …",
  "Add …", "Allow …", "Speed up …" — no "now", no "This PR".
- No code identifiers, no backticks, no class/method/file names in
  the sentence text itself.
- **No developer or UI-implementation jargon** (Joe, 2026-08-24
  Article review). Replace it with what the user sees:
  - "lightbox" → "the enlarged image" / "the enlarged image view"
  - "modal" → "pop-up" / "dialog", or rewrite without it
  - "500", "crash", "race" → "error" / "bug"
  - "parameter" / "param" — this word almost always means the entry
    is describing an internal detail, not a user-facing change. Take
    it as a signal to either rewrite the sentence for the user or set
    `article: no`.
- **Capitalize MO object names, singular and plural** (Joe, same
  review): Observation(s), Name(s), Location(s), Project(s), Image(s),
  Occurrence(s), Field Slip(s), Species List(s), Herbarium/Herbaria,
  Naming(s), Sequence(s), Comment(s), Description(s), Publication(s),
  User(s), Checklist(s), External Link(s). Leave everyday words
  lowercase (photo, thumbnail, collector, admin as a role).
- No PR/issue numbers — the generator adds the links.
- Capitalized, no ending punctuation.

These wording rules are the place feedback from Article reviews
lands: when a reviewer trims or rewords rows, the pattern behind the
edit belongs here, so the next block is written that way to begin
with.

## Format is machine-parsed — keep it exact

The generators read everything between `<!-- changelog -->` and
`<!-- /changelog -->`: the first non-blank line must be
`article: yes` or `article: no`; the remaining non-blank lines are the
sentence. A block that does not parse is treated as absent (excluded
from the Article, flagged for manual review). When a description
quotes an example block, the *last* block in the body is the one that
counts.

## Producing the Article rows

`script/article_rows.rb --since YYYY-MM-DD [--until YYYY-MM-DD]`
prints one Textile row per `article: yes` PR merged in the range,
newest first, and lists the blockless PRs on stderr for a human
verdict. Paste the rows into the Article by hand (they go under the
blank separator row, newest first).
