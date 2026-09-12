# Visual spacing in new UI — assume you can't see it, because you can't

## The failure mode

Claude sessions build and verify UI through tests, RuboCop, and HTTP
responses — none of which render pixels. A button jammed flush against
the image above it produces exactly the same green test suite as one
with comfortable margins, so nothing in the session's feedback loop
ever flags it. And the testing conventions (correctly) forbid pinning
cosmetic spacing classes in tests, so there is no regression signal
for polish either. The result, observed repeatedly across sessions and
developers: structurally correct pages whose interactive elements
touch their neighbors.

Concrete example (PR #5044): the observation scan page rendered each
photo's "Read Field Slip" button flush against the photo's bottom
edge. Correct DOM, passing tests, visibly cramped.

## The rule

When composing a new page or section, don't write bare structure and
stop when tests pass:

1. **Copy the spacing idiom from an existing page with the same
   shape.** Before writing a photo-grid, a button row, a label+control
   stack, find one already in `app/views/controllers/` or
   `app/components/` and match its margin/padding utility classes —
   don't reason spacing out from scratch.
2. **Any interactive control adjacent to an image or other media gets
   an explicit margin** (`mt-2` on the row below a photo, `ml-2`/
   `mr-2` beside one). Media elements have hard visual edges; text has
   built-in line spacing, images have none.
3. **Blocks stacked inside a panel or cell need vertical separation**
   — a bare `div { ... }` directly under another rendered element is
   the tell. If two siblings would touch, the second one needs a
   `mt-*`.

## What this doesn't replace

A human looking at the rendered page. Spacing utilities applied by
convention get new UI to "reasonable by default," not "reviewed."
Flag visually novel layouts for a human glance in the PR's test plan.
