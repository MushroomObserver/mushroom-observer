# Sweeps — scope guidance

A "sweep" is a task whose stated scope is already broad by definition —
"remove `User.current` from the model layer," "route raw Bootstrap
`col-*` classes through `Grid` constants," "convert every
`app/helpers/tabs/*_helper.rb` to a Tab PORO." The scope was set when
the sweep was named, not when the PR is drawn.

**Don't re-derive a narrower scope than the sweep already declared.**
The normal instinct — keep a PR small, single-purpose, easy to review —
still applies to *ordinary* changes, but it actively fights a sweep. If
the sweep's stated target is "all models" or "the whole directory,"
splitting it into one-model-at-a-time or one-file-at-a-time PRs doesn't
make review easier; it just multiplies the fixed overhead (branch,
tests, rubocop, PR description, coveralls check) across many PRs that
all repeat the same reasoning.

**Rule of thumb:** when a sweep's declared scope is "all X" (all
models, all controllers, all call sites of a pattern), the right unit
of a single PR is **one X** — e.g. one whole model (`Name` +
everywhere it's read/written), not one method or one file within it.
Splitting further than that is over-limiting; each PR should still be
the *complete* treatment of its one unit, not a partial pass that
leaves known follow-up work for "later."

**What this means in practice:**
- If a sweep says "remove `User.current` from the model layer" and
  you're doing `Name`, do all of `app/models/name.rb` +
  `app/models/name/*.rb` in one PR — every read site, every write
  site, every caller that needs to thread a value through — not just
  the one method that was easiest to fix first.
- Don't invent an artificial split ("just the callback sites this
  time, the display-name defaults next time") when the user asked for
  the whole model. If a genuinely separate concern turns up mid-sweep
  (a different model's parallel mechanism, a pre-existing bug in
  shared code unrelated to the sweep's target), flag it and carve it
  out explicitly — don't silently narrow the PR to avoid finishing.
- Still split across *models* (or whatever the sweep's declared unit
  is) — "do all of `Name`" is one PR; "do all of `NameDescription`" is
  the next one. The sweep is the umbrella; each PR is one complete
  unit under it.

This complements, not overrides, the general PR-scope instincts
elsewhere in this doc — ordinary bug fixes and features should still
stay small and focused. Sweeps are the deliberate exception, because
their entire point is to touch a lot of surface area consistently.
