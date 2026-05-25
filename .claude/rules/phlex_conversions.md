---
paths: app/components/**/*.rb, app/views/**/*.rb, app/views/**/*.erb
---

# Phlex Conversions

## Decide first: reusable or single-use?

The first decision when converting an ERB helper / partial / template to
Phlex is **where the new Phlex class lives**. Make this decision before
writing any code — it determines the namespace, the file path, the test
location, and how reviewers reason about reuse.

- **Reusable component** → `app/components/<name>.rb`, class
  `Components::<Name>` (flat namespace), tests in `test/components/`.
  Use this when the class is genuinely intended to be rendered from more
  than one controller, or one obvious second caller already exists.

- **Single-use view file** → `app/views/controllers/<controller>/<name>.rb`,
  class `Views::Controllers::<Controller>::<Name>` (deep namespace
  mirroring the controller tree), tests in `test/views/controllers/...`.
  Use this when the class only renders for one controller's pages,
  including the case where the only "second caller" is a turbo_stream
  response in that same controller.

Both inherit from `Phlex::HTML` via `Components::Base` (`Views::Base` is
a thin subclass). The split is for organization and intent, not
capability — they can do the same things.

Why this matters:

- **`app/views/` stays organized like the ERB tree it replaces.** A
  Phlex single-use view sits next to the action templates it serves —
  the same place a partial used to live. Reviewers find it where they
  expect.
- **`app/components/` stays small and meaningful.** It contains real
  building blocks, not page-specific fragments. Putting a page-specific
  fragment there implies "reuse me elsewhere" — an invitation that
  rarely turns out well.
- **Eventually action templates themselves migrate to Phlex.** When
  `index.html.erb` becomes `index.rb`, it joins the same
  `app/views/controllers/<controller>/` directory as the partial-
  equivalents already there. The structure scales.

If a single-use class becomes reusable later, move it: rename file,
flatten namespace, update callers. Cheap refactor. Don't speculatively
put a single-use class in `app/components/` "just in case."

Example of the single-use pattern: see
`app/views/controllers/account/api_keys/table.rb`
(`Views::Controllers::Account::APIKeys::Table`) — the api_keys index
table chunk, rendered by both the index page and the post-CUD
turbo_stream response, both within the api_keys controller.

## Collapse deep namespaces in `Views::Controllers::*`

The `Views::Controllers::<Controller>::<Name>` namespace is four levels
deep for most controllers (deeper for nested controllers like
`Account::APIKeys`). **Do not** indent four times. Open the whole chain
in a single declaration:

```ruby
# DO
module Views::Controllers::Account::APIKeys
  class Table < Views::Base
    def view_template
      # ...
    end
  end
end

# DON'T
module Views
  module Controllers
    module Account
      module APIKeys
        class Table < Views::Base
          def view_template
            # ...                  # body buried at 10 spaces
          end
        end
      end
    end
  end
end
```

This works because the parent namespaces (`Views`, `Views::Controllers`,
etc.) are already autoloadable — Zeitwerk discovers them from the
directory structure once `app/views/` is registered with
`namespace: Views` in `config/initializers/phlex.rb`. Ruby will resolve
the chain when it evaluates the `module` line.

Apply the same shorthand in tests:

```ruby
module Views::Controllers::Account::APIKeys
  class TableTest < ComponentTestCase
    # ...
  end
end
```

Inside the namespace, sibling classes reference each other unqualified:
`render(Form.new(...))` rather than the full
`render(Views::Controllers::Account::APIKeys::Form.new(...))`.

## Phlex Form Conversions

Before writing ANY Phlex form component, you MUST:

1. Read `.claude/phlex_style_guide.md` in full
2. Read `app/components/application_form.rb` for the base class API, then
   `app/components/application_form/field_helpers.rb` for all available
   field helpers (`text_field`, `textarea_field`, `checkbox_field`, etc.)
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

### Watch for a decorative `Model.new` passed to `super`

If your form has bound fields, pass the real model (or a real FormObject)
that actually backs them. The anti-pattern is passing a throwaway
`Foo.new` *just* to make Superform happy, then hand-rolling every input
with raw `name=` strings.

```ruby
# ❌ Anti-pattern. The Occurrence is decorative — nothing binds to it.
class Components::OccurrenceResolveForm < Components::ApplicationForm
  def initialize(gaps:, primary:, selected: nil, **)
    @gaps = gaps; @primary = primary; @selected = selected
    super(Occurrence.new, **)
  end

  def selected_hidden_fields
    # Hand-rolled because nothing binds to the model:
    @selected.each { |obs| hidden_field("occurrence[observation_ids][]", value: obs.id) }
    hidden_field("occurrence[primary_observation_id]", value: @primary.id)
  end
end

# ✅ Fix: introduce a FormObject that *actually* represents the form's data.
class FormObject::OccurrenceProjects < FormObject::Base
  attribute :resolution, :string
  attribute :primary_observation_id, :integer
  attribute :observation_ids, default: -> { [] }
end

class Components::OccurrenceProjectsForm < Components::ApplicationForm
  def initialize(gaps:, primary:, selected: nil, **)
    # ...
    super(build_form_object, **)
  end

  def selected_hidden_fields
    hidden_field(:primary_observation_id)   # Symbol path → bound + namespaced
    # ...
  end
end
```

**Why it matters:**

- Misleading: a reader sees `Occurrence.new` and thinks "this form
  edits an Occurrence." It doesn't.
- Defeats Superform: the `<form_name>[<field>]` param namespacing,
  PATCH-vs-POST method picking via `model.persisted?`, and field
  binding all stop working as designed.
- Often comes with a route mismatch: the decorative model
  silently flips `_method=patch` on or off (depending on
  `persisted?`), so the form submits to the wrong HTTP verb.

**Fuzzy cases.** It isn't always black-and-white. Real forms sometimes
sit on a gradient between "this is an `X` form" and "this is an
operation that incidentally touches `X`." Some signs you're in fuzzy
territory:

- Most fields bind to the model, but one or two are operation-specific
  (e.g. a `confirm_email` checkbox on an Account edit form). Stay on
  the real model and let those one-offs ride along — they don't
  justify a FormObject.
- The form's params end up shaped exactly like `<model_name>[...]`
  by design, even though the data is operation state. Then the model
  *is* a fair stand-in for what the controller will read; passing it
  isn't decorative.
- The model is real but most fields don't bind to it directly — the
  form is mostly hidden re-submissions of selection state plus a
  resolution choice. That's the case where a FormObject is the right
  fix (e.g. `FormObject::OccurrenceProjects`).

If the decision isn't obvious, ask: *would a future reader, looking at
the constructor's first argument, infer what the form does?* If not,
the model is decorative — refactor.

(Rule added after the `OccurrenceResolveForm` → `OccurrenceProjectsForm`
refactor in #4345.)

After writing the component:

4. Write a component test in `test/components/` following the patterns in
   `.claude/rules/testing.md` (consolidate assertions per render, extract
   a DRY render helper, etc.). See `test/components/herbarium_form_test.rb`
   or `test/components/sequence_form_test.rb` for reference.
5. Self-review the component diff for any literal `input(`, `select(`,
   `textarea(`, or `option(` calls. If present, replace each with the
   helper or FieldProxy pattern before opening the PR.
6. **If the component replaces an ERB modal or form, run an HTML-parity
   diff against the pre-refactor markup before opening the PR.** Use the
   diff harness pattern from `.claude/rules/testing.md`
   ("Debugging Phlex Component Conversions / The HTML Diff Technique"):
   keep a renamed `_Old` copy of the original component on the branch,
   write a one-off test that renders both with identical inputs and
   writes them to `/tmp/foo_old.html` + `/tmp/foo_new.html`, then `diff`
   the formatted output.

   For every difference, decide:
   - **Preserve** it via `wrapper_options: { wrap_class: ... }` on
     collection fields, `wrap_class:` on field helpers, explicit Phlex
     `class:` attrs, or whatever knob the new component exposes. Common
     drops to look for: `.mb-2` on `.radio` / `.checkbox` rows,
     `text-right`/`mt-3` on button rows, custom `data-*` attributes,
     ARIA labels, the modal's `.modal-header` vs. `.modal-body` /
     `.modal-footer` placement of submit buttons. See
     `phlex_style_guide.md` — `Form Inside a Modal` for the modal-form
     case specifically.
   - **Call it out** explicitly in the PR description if you're
     intentionally changing the markup (e.g. adding `.fade` for animation
     consistency, dropping an unused id). Reviewers shouldn't have to
     spot drift in a diff that calls itself "no functional change".

   This is mandatory for modal/form ERB→Phlex conversions — the visual
   contract there is easy to drift on, and reviewers can't catch it
   without the diff (controller / component tests are happy with either
   markup). For non-form, non-modal components the diff is still a good
   habit but isn't required.
