---
paths: app/components/**/*.rb, app/views/**/*.rb, app/views/**/*.erb
---

# Phlex Conversions

## Decide first: reusable or single-use?

The first decision when converting an ERB helper / partial / template to
Phlex is **where the new Phlex class lives**. Make this decision before
writing any code — it determines the namespace, the file path, the test
location, and how reviewers reason about reuse.

**Default placement when converting an ERB view to Phlex.** ERB files
living under `app/views/` get converted to Phlex classes under
`app/views/controllers/<controller>/<name>.rb`. This applies to
*everything* in the views tree — forms, tables, panels, sidebars, navs,
modals, headers, page wrappers, footers, list rows, partials of any
kind. The default is the views tree, not `app/components/`.

**Exception: true UI primitives.** If while converting you extract a
chunk that's a genuine, reusable UI building block — a button group, a
badge, an alert, a generic widget that you'd recognize as a
"component" regardless of where it happens to be rendered today —
that piece can live in `app/components/` even if only one caller
currently exists. The "speculated future caller" carve-out applies
*only* to recognizably-generic UI primitives. It does NOT apply to
page-specific fragments wearing component clothing (e.g. a
`Components::WhateverShowDetails` that only ever renders one
controller's show page — that's a view, put it in
`app/views/controllers/`).

Heuristic: would a reader who doesn't know this codebase look at the
class name and the file's contents and say "yes, that's a component"?
If yes, `app/components/`. If they'd say "that's the
`whatever_controller`'s `show` page", `app/views/controllers/`.

- **Single-use view file (default for ERB conversions)** →
  `app/views/controllers/<controller>/<name>.rb`, class
  `Views::Controllers::<Controller>::<Name>` (deep namespace mirroring
  the controller tree), tests in `test/views/controllers/...`. Use this
  when the class only renders for one controller's pages, including
  the case where the only "second caller" is a turbo_stream response
  in that same controller.

- **Reusable component (UI primitives or genuinely multi-caller)** →
  `app/components/<name>.rb`, class `Components::<Name>` (flat
  namespace), tests in `test/components/`. Use this for true UI
  building blocks (button groups, badges, alerts, etc.) regardless of
  current caller count, OR for non-primitive classes that already have
  a concrete second caller.

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

## Helpers available everywhere — no per-class registration

A handful of helper sources are wired into the Phlex base classes:

- **`Components::Base`** registers app-wide helpers: `q_param`,
  `add_q_param`, `url_for`, `permission?`, `link_to_object`,
  `user_link`, `location_link`, `link_icon`, `help_block`,
  `make_table`, etc. — see the registration block at the top of
  `app/components/base.rb` for the full list.
- **`Components::Base`** also includes `Phlex::Rails::Helpers::Routes`
  (every named route helper — `foo_path`, `bar_url`),
  `Phlex::Rails::Helpers::AssetPath` (`asset_path`),
  `Phlex::Rails::Helpers::LinkTo` (`link_to`),
  `Phlex::Rails::Helpers::ButtonTo` (`button_to`),
  `Phlex::Rails::Helpers::ClassNames` (`class_names`), and
  `Phlex::Rails::Helpers::TurboFrameTag` (`turbo_frame_tag`).
- **`Views::Base`** layers on the page-chrome helpers:
  `add_page_title`, `add_new_title`, `add_edit_title`,
  `add_context_nav`, `add_project_banner`, `container_class`,
  `content_for`.
- **`Views::Base`** also includes every top-level `Tabs::*Helper`
  module via a `to_prepare` hook in `config/initializers/phlex.rb`.
  Any tab builder (`object_return_tab(...)`,
  `species_lists_index_tabs(...)`, `inat_import_form_new_tabs(...)`,
  etc.) is callable from any view as if it were a class method.
  Nested modules under `Tabs::Sidebar::*`, `Tabs::Locations::*`,
  `Tabs::Names::*` are NOT auto-included — they stay scoped to
  their specific callers.

**Don't `register_value_helper`** for anything in those buckets.
The registration is a no-op duplicate.

If your view needs a helper that isn't in any of those buckets, it
falls into the move-vs-register decision below.

## Moving a helper into a Phlex view

When converting an action template to Phlex, you'll often find page
logic spread between the ERB and `app/helpers/...` modules. The
helpers either need to move into the Phlex view class (cleaner) or
stay registered as helpers (looser coupling). Choosing wrong leads
to nasty failures, so:

**Move a helper method into the Phlex view when** its body is
self-contained — symbol/translation lookups, model attribute reads,
plain Ruby. No calls to *other* helper methods.

Example — `checklist_show_title` (used by
`Views::Controllers::Checklists::Show`) is pure `:foo.t` lookups.
Moves cleanly as a private method on the view class.

```ruby
# Before — in app/helpers/tabs/checklists_helper.rb
def checklist_show_title(user:, list:)
  if user      then :checklist_for_user_title.t(user: user.legal_name)
  elsif list   then :checklist_for_species_list_title.t(list: list.title)
  else              :checklist_for_site_title.t
  end
end

# After — inline in Views::Controllers::Checklists::Show
private def checklist_show_title
  user, list = @context.show_user, @context.species_list
  if user      then :checklist_for_user_title.t(user: user.legal_name)
  elsif list   then :checklist_for_species_list_title.t(list: list.title)
  else              :checklist_for_site_title.t
  end
end
```

**Keep it registered (do NOT move) when** the body calls other
helper methods — e.g. tab builders that compose
`user_profile_tab`, `show_object_tab`, `email_user_question_tab`,
etc. across multiple `Tabs::*Helper` modules.

```ruby
# Stays in app/helpers/tabs/checklists_helper.rb — calls helpers
# in Users / Info / SpeciesLists / etc. modules
def checklist_show_tabs(user:, list:)
  if user    then checklist_for_user_tabs(user)
  ...
end

# In the Phlex view class:
register_value_helper :checklist_show_tabs
```

**Why "moving multi-helper methods" doesn't work yet.** Inside a
Phlex view, `helpers.foo(...)` only resolves to *registered*
helpers; everything else surfaces as
`NoMethodError: private method 'foo' called for an instance of ...`.
So if you move `checklist_show_tabs` into the view but its body
still calls `user_profile_tab(user)` etc., you'd have to:

- register each transitively-used helper (cascading; one move
  drags in 5–10 registrations), or
- `include Tabs::UsersHelper`, `include Tabs::InfoHelper`, … —
  multiple module includes per view to restore helper-chain
  transparency.

Neither is paying for itself today. **Eventually** we want a
mechanism that exposes the full tab-helper namespace to Phlex
views without explicit `helpers.*` or per-method registration; until
then, leave multi-helper methods registered.

Heuristic to apply during a conversion:

- Body is `:symbol.t(...)`, model attribute reads, plain Ruby? →
  **move into the view** as a private method.
- Body calls *any* method that isn't on `self` or a Ruby standard
  library? → **leave in the helper module**, `register_value_helper`
  on the view.

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
