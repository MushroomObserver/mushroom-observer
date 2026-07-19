# Code comments: explain *why* (only when unclear), one source of truth

Two rules for every comment in this codebase — app code, tests, config,
`Gemfile`, scripts, everywhere.

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

## Why this is a rule

Comments that restate the code, or repeat a rationale in three places,
rot. Whoever changes the behavior next has to find and fix every copy;
the ones they miss actively mislead. A single, well-placed *why*
survives; a paragraph duplicated into every related file does not.

Durable, cross-cutting rationale ("why the project does X") belongs in
these `.claude/rules/` files or the PR/issue thread — which persist and
are searched — not sprinkled through code comments. Code comments only
help at the moment someone is editing that code.
