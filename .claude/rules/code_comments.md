# Code comments: explain *why* (only when unclear), one source of truth

Four rules for every comment in this codebase — app code, tests,
config, `Gemfile`, scripts, everywhere.

## 1. Comment the *why*, and only when it isn't already clear

A comment earns its place only when it captures something the code
*can't* say on its own: a non-obvious rationale, a gotcha, a deliberate
choice that looks wrong but isn't, a pointer to context (an issue, a
spec quirk). Do **not** restate what the code plainly does, and do not
explain the obvious.

```ruby
# BAD — restates the code
# Set the size to medium
@size = :medium

# BAD — explains the obvious
# Loop over the users
users.each { |u| ... }

# GOOD — non-obvious *why*
# insert_before(0) so this runs ahead of Rails' own param-filtering,
# which itself raises on invalid UTF-8.
config.middleware.insert_before(0, Rack::UTF8Sanitizer)
```

Prefer making the code self-explanatory — a well-named method, an
extracted predicate — over adding a comment to explain unclear code.

## 2. Single source of truth

When a rationale *is* worth writing, write it once, at the load-bearing
site — where the non-obvious decision actually lives. Everywhere else
that touches the same thing, use a brief pointer (`# see
config/application.rb`), never a re-explanation.

Repeating the same rationale across files (the `Gemfile`, the config,
and the test all explaining the same middleware) adds no safety — a
reader has the whole change in view — and multiplies the staleness
surface: change the behavior, and every copy you miss becomes a *lying*
comment, which is worse than no comment.

## 3. Terse, not narrative — no changelog framing, no issue links

A comment states the current fact about the code, not the story of how
it got there. Never write:

- A step-by-step narrative of what the code does — the code already
  reads that way, statement by statement.
- "This replaces X" / "instead of Y" / "rather than Z" framing that
  compares against a former version. The old version is gone; a
  reader only ever sees what's here now — `git blame`/`git log`
  already hold the history.
- PR or GitHub issue references (`#4894`, `PR #4977`) inside a code
  comment. That context belongs in the commit message and PR
  description, not baked into the source forever.

```scss
// BAD — narrative, compares to a former version, references a PR,
// way longer than the one-line selector it's attached to
// Padding/color/hover live on the inner <button>, not the
// <form.button_to> wrapper -- the form is a thin, unpadded shell
// (Rails' button_to requirement), so a hover background painted on
// the button alone would only fill its tight text box instead of
// the full bordered/padded segment the form defines. Scoped through
// `.vote-btn-group` (a real `.btn-group`) rather than just
// `form.button_to button[type=submit].image-vote-link`, since
// Bootstrap's own `.btn-group` CSS is a plausible source of
// conflicting button styling to out-specify (Copilot review on PR
// #4977).
.vote-btn-group form.button_to button[type=submit].image-vote-link { ... }

// GOOD — states the current fact, nothing more
// Padding/hover live on the button, not the form -- the form has none.
.vote-btn-group form.button_to button[type=submit].image-vote-link { ... }
```

If a comment needs several sentences to justify a rule, that's usually
a sign the *code* should be simpler — not that the comment should be
longer.

## 4. Cut redundant possessives — write plainly

"X's own Y" almost always just means "X's Y" — the possessive already
says whose it is; "own" adds nothing. Cut it outright rather than
finding a synonym.

```ruby
# BAD — "own" is padding; "the model's" already says whose scope it is
# An exact match is already prioritized by the model's own `pattern`
# scope.

# GOOD
# An exact match is already prioritized by the model's `pattern` scope.
```

Same principle for other padding that doesn't add information — write
short, declarative sentences, not stacked qualifiers or a parenthetical
inside a parenthetical. If a sentence reads awkwardly once the padding
is cut, restructure the sentence — don't put the padding back.

## Why this is a rule

Comments that restate the code, or repeat a rationale in three places,
rot. Whoever changes the behavior next has to find and fix every copy;
the ones they miss actively mislead. A single, well-placed *why*
survives; a paragraph duplicated into every related file does not.

Durable, cross-cutting rationale ("why the project does X") belongs in
these `.claude/rules/` files or the PR/issue thread — which persist and
are searched — not sprinkled through code comments. Code comments only
help at the moment someone is editing that code.
