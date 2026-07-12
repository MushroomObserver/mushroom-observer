# Reply to fixed Copilot findings on the PR thread, don't re-verify from scratch

When a Copilot (or other automated) review comment is addressed, reply
in that comment's thread on the PR saying so — don't rely on the
commit message or a fresh read of the code to reconstruct whether it
was handled. Copilot re-reviews on every push, and stacked/rebased PRs
carry the same findings forward across branches; without a reply on
the thread itself, every subsequent review pass (and every session
picking the branch back up) re-derives from scratch whether a given
finding was already fixed, by re-reading the surrounding logic and
reconstructing the reasoning. That's wasted, repeated effort — the
answer was already worked out once.

**Do not add in-code comments to mark a finding as "Copilot flagged,
already fixed."** That clutters the source with review-process noise
that has nothing to do with the code's own logic. The PR comment
thread is the right place for review-process bookkeeping; the code
should only ever explain the code.

## Convention

Reply on the specific review comment (via `gh api
repos/OWNER/REPO/pulls/PR/comments/COMMENT_ID/replies` or the
equivalent), stating what was fixed and how:

```
Fixed in <commit-ish> - <one-line description of the fix>.
```

or, if it was already fixed by an earlier commit before this review
pass even ran:

```
Already fixed as of <commit-ish> (<one-line reason>) - no change needed here.
```

## When a finding was a deliberate design choice, not a bug

Some Copilot findings point at behavior that's intentional — a
tradeoff made on purpose, not an oversight. Reply on the thread
explaining the tradeoff, AND put the same reasoning in a code comment
at the site itself (that part belongs in the code, since a future
reader of the code — not just the PR — needs to know it was
deliberate):

```
Reply on the PR thread:
Intentional - broadcasting to every subscribed page can't reconstruct
per-page props, so the re-render falls back to a plain default view.
Not certain it's the final right call; see the comment at the call site.

Code comment at the call site:
# Turbo-stream re-render intentionally drops call-site props (image_link,
# votes, extra_classes, etc.) -- broadcasting to every subscribed page
# can't reconstruct per-page props, so it falls back to a plain default
# view. Whether that's the right tradeoff is still open.
```

## Why this is a hard rule, not a nice-to-have

Skipping the PR-thread reply is exactly what caused repeated
re-verification across the `nimmo-4735-*` PR stack (#4751/#4749/#4752)
- the same ~9 findings got manually re-confirmed as already-fixed
multiple times across sessions, each requiring a fresh read of the
surrounding logic. A reply on the thread turns that into "already
answered, scroll up" instead of a re-derivation.
