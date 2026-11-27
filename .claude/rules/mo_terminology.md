# MO vocabulary — use the words MO uses

Where MO has a word for something, use it. A synonym costs a reader a
translation step, and when the synonym carries other everyday meanings
it loses them.

## Say "Observation", not the noun "find"

**One substitution: where you would write "a find", "the find",
"finds" or "a project's finds" and you mean an Observation, write
Observation.**

It holds for the whole codebase, not one corner of it, and for
everything written about it — code, comments, test names, commit
messages, PR and issue text, changelog sentences, email copy, chat.
The project-alert code is where the word crept in, which is why the
first cleanup landed there, but nothing about the rule is particular
to it.

| Instead of | Write |
| --- | --- |
| a find | an Observation |
| a rare find | a rare Observation |
| the project's finds | the Observations the project holds |
| a run of finds | a run of Observations |
| the find this project was told about | the Observation this project was told about |

### This is not a swap of "find" for "new observation"

A sentence whose subject is which kind of alert a row belongs to is a
separate job. There the words are the kinds themselves —
`new_observation` and `other_activity`, which the emails render as
"New observations" and "Other activity" — so "reported as new" or
"reported as activity" is naming a kind, not standing in for the word
this rule is about. Most uses are not that case and want plain
Observation.

### The verb is untouched

"The query finds observations", `find_by`, `Observation.find(id)`,
"find out which project it belongs to", the Unix `find` command: all
fine, all unrelated.

## Why

Nathan, 2026-11-24, on a changelog sentence written during the
project-alert work: *"The use of 'finds' for 'observations' seems like
a new habit in this claude session and I don't really like it. It
seems like new confusing jargon using a term that has a lot of
different meanings."* The word had spread through #5677, #5705, #5768
and #5780 — one method name, four translation tags, and comments
across six files — before anyone said so. It was cleaned up in PR
#5785; the rule is here so it does not come back one comment at a
time.

## Enforcement

`.claude/hooks/block_banned_words.sh` blocks the noun shapes in file
writes, commit messages and `gh` issue/PR bodies, alongside the
intensifier list in
[gh_pr_issue_formatting.md](gh_pr_issue_formatting.md).

A hit needs two things on one line: the word directly after an
article, a possessive or "of", AND one of a short list of MO record
words (observation, project, alert, iNat, naming, taxon, coordinator,
herbarium, specimen, voucher, species list, field slip). The second
half is there to keep the ordinary English senses out — "the find
command", "a find in the log output" — not to limit the rule to one
area of the code. An earlier revision keyed on the grammar alone and
blocked every one of those; a wider word list put them back, since
"retransfer_images and the find -mmin +3" carries the word "image".

The cost is a miss where the noun sits on a line carrying no such
word. This doc covers that case, not the hook: the hook is a backstop
for the shapes seen so far, not the rule. A false positive gets
rephrased, not bypassed. Files under `.claude/` are skipped, so a rule
doc can quote the words it bans.
