# MO vocabulary — use the project's own words

Domain terms MO already has a word for. Inventing a synonym costs a
reader a translation step and, when the synonym has other everyday
meanings, loses them.

## Never "a find" for an Observation

**Do not write "a find", "the find", "finds", or "a project's finds"
to mean an Observation** — in code, comments, test names, commit
messages, PR and issue text, changelog sentences, email copy, or chat.

Write **Observation**. Where the point is which kind of alert a row
belongs to, name the kind: a **new observation** or **activity** on one
the project already has. Those two are what `ProjectAlert`'s `kind`
column holds (`new_observation`, `other_activity`), and the emails
themselves say "New observations" and "Other activity" — so the plain
vocabulary was there the whole time.

| Instead of | Write |
| --- | --- |
| a find | an Observation, or a new Observation |
| the project's finds | the Observations the project holds |
| reported as a find | reported as a new Observation |
| tells a find from activity | tells a new observation from activity |
| a run of finds | a run of new-observation messages |

The verb is fine, and so is everything built on it: "the query finds
observations", `find_by`, "find out which project it belongs to".

**Why.** Nathan, 2026-11-24, on a changelog sentence written during the
project-alert work: *"The use of 'finds' for 'observations' seems like a
new habit in this claude session and I don't really like it. It seems
like new confusing jargon using a term that has a lot of different
meanings."* The word spread through #5677, #5705, #5768 and #5780 — one
method name, four translation tags, and comments across the ledger, the
collector, the poll, the criteria and the mailer — before anyone said
so. It was scrubbed in PR #5782; the rule is here so it does not come
back one comment at a time.

## Enforcement

`.claude/hooks/block_banned_words.sh` blocks the noun shapes — "find"
or "finds" directly after an article, a possessive, or "of" — in file
writes, commit messages and `gh` issue/PR bodies, alongside the
intensifier list in
[gh_pr_issue_formatting.md](gh_pr_issue_formatting.md). A false
positive gets rephrased, not bypassed. Files under `.claude/` are
skipped, so a rule doc can quote the words it bans.
