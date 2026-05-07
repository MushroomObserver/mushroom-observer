---
paths: app/components/**/*.rb, app/views/**/*.erb
---

# Phlex Form Conversions

Before writing ANY Phlex form component, you MUST:

1. Read `.claude/phlex_style_guide.md` in full
2. Read `app/components/application_form.rb` to understand available field
   helpers and the base class API
3. Read an existing form component as a reference (e.g.
   `app/components/herbarium_form.rb`, `app/components/name_form.rb`)

Do NOT skip these reads even if the conversion seems straightforward.

While writing the component, for **every** form control you add, follow the
"NEVER hand-roll form-control HTML" decision tree in `phlex_style_guide.md`:

- Field is on the model / FormObject? → use the matching `*_field` helper.
- Field isn't on the model? → wrap it with
  `Components::ApplicationForm::FieldProxy` and render the matching field
  class (`RadioField`, `TextField`, `CheckboxField`, `SelectField`, …).
- **Never** emit raw `input`, `select`, `textarea`, or `option` tags from a
  form component. If you find yourself reaching for them, you're missing
  one of the two paths above. Re-read the FieldProxy section before
  proceeding. (This rule was added after PR #4224 had to undo a hand-rolled
  radio group from PR #4076.)

After writing the component:

4. Write a component test in `test/components/` following the patterns in
   `.claude/rules/testing.md` (consolidate assertions per render, extract
   a DRY render helper, etc.). See `test/components/herbarium_form_test.rb`
   or `test/components/sequence_form_test.rb` for reference.
5. Self-review the component diff for any literal `input(`, `select(`,
   `textarea(`, or `option(` calls. If present, replace each with the
   helper or FieldProxy pattern before opening the PR.
