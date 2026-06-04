---
paths: app/components/**/*.rb, app/views/**/*.rb, app/views/**/*.erb
---

# Phlex Conversions

## The scope is the ERB **and** its helpers — every time

Every Phlex conversion PR has two halves, and both are in scope. The
loud half is the ERB file you're replacing. The quiet half is the
helper code that ERB calls — `app/helpers/<thing>_helper.rb` methods,
private partial-builders, hash/array-shape "data" methods, anything
the ERB pulls in to render itself. **Inline every helper you can on
the same PR.**

Why this is non-negotiable:

- The point of moving to Phlex is to put *all* of a page's rendering
  logic in one Ruby class — methods, conditionals, helpers, the lot.
  If you leave the helper behind, you've moved the markup but
  scattered the logic across two files. Reviewers and future readers
  still have to chase the same render across the same two places.
- ERB-era helpers were the workaround for ERB being a bad place to
  write Ruby. In a Phlex view, you have private methods, normal
  control flow, and `register_*_helper` for the cases where you
  really do need the Rails helper context. Most helpers stop earning
  their keep the moment the view becomes Phlex.
- Helpers accumulate quietly. A "just the markup" conversion that
  defers the helper to a later PR almost always leaves the helper
  there permanently — there's no natural next trigger to come back
  to it. Touch it now, finish it.

Apply the move-vs-register heuristic in "Moving a helper into a Phlex
view" below to every helper the ERB calls:

- Self-contained body (`:symbol.t` lookups, model attribute reads,
  plain Ruby, calls only to itself) → **inline as a private method
  on the new Phlex view** (or extract a sibling Phlex class if the
  helper is doing something a class deserves to own — e.g. row
  construction for a table → an `Aliases::Table` view).
- Body composes other helpers (tab builders, etc.) → leave registered
  for now (`register_value_helper`), with a comment.

By the end of the PR, the helper file should be measurably smaller —
ideally empty and deleted. PR descriptions should call out the
helper-side cleanup explicitly so reviewers can see both halves of
the work. If you find yourself opening a follow-up PR purely to
inline helpers from a conversion you just shipped, the conversion
was incomplete.

## `register_value_helper` is a code smell — ask before you reach for it

The conversion goal is to **eliminate** the helper, not paper it
over with a thin Phlex wrapper that still depends on it. Every
`register_value_helper :foo` line says "this view depends on
`foo` as a contract" and gives future readers a reason to leave
`foo` alone. That defeats the refactor.

**Hard rule:** before adding a `register_value_helper` line, **stop
and ask the user**. Lead the ask with the reminder that this
refactor is about refactoring helpers, not just views, and
explain why you think this specific helper can't be inlined.
Default to inlining the helper's logic as private methods on the
new view (per the move-vs-register heuristic above). The user has
to explicitly approve the registration — the default answer is
"no."

The carve-outs above ("Body composes other helpers → leave
registered for now") still exist, but treat them as the exception
that needs justification, not the easy path. The kinds of helpers
that may be OK to register (when nothing else works):

- **Stable request-context predicates** that all controllers expose
  and that no refactor will ever delete — `in_admin_mode?`,
  `reviewer?`, `permission?`, `controller`, `params`,
  `add_page_title`. These are already registered in
  `Components::Base` / `Views::Base` / `Components::ApplicationForm`;
  if a new view needs one of those that isn't yet registered on the
  base class, registering it on the appropriate base (so the whole
  class hierarchy benefits) is the right move. Ask first to confirm
  the scope (base class vs single view).
- **Helpers whose body itself composes 5+ other helpers** AND none
  of those helpers are domain helpers the user is trying to delete.
  Rare in this codebase.

**Domain helpers the user is actively trying to delete**
(`list_descriptions`, every `tabs/*_helper.rb` method,
`add_list_of_projects`, etc.) **never** belong in
`register_value_helper`. Inline the logic into the new view as
private methods, even if it makes the view 100+ lines. The Phlex
view owning its own render chain is the whole point.

**Never call `helpers.foo` from inside a Phlex view.** It's not a
substitute for registering — it's worse (silent runtime
dispatch into ActionView, brittle across Phlex versions). If
`foo` needs to be reachable from the view, either inline it or go
through the proper registration channels.

This rule was added after a conversion shipped a
`register_value_helper :list_descriptions` in
`Views::Controllers::Descriptions::List` — the helper that PR was
nominally trying to deprecate. Don't repeat that mistake.

## ALWAYS use concrete prop types — never `_Any` when the type is known

Phlex props validate at construction time when you give them a
concrete type (`prop :user, ::User`, `prop :siblings,
_Array(::Observation)`). A wrong-type arg fails loudly at the
construction site instead of at the first method call that
trips over `nil`. That's most of the value of having props at
all — `_Any` throws the typecheck away.

**Hard rule:** when you know the class an arg will hold, use it
literally:

```ruby
# ✅ DO — concrete classes catch caller mistakes at construction
prop :obs, ::Observation
prop :consensus, _Nilable(::Observation::NamingConsensus), default: nil
prop :siblings, _Array(::Observation), default: -> { [] }
prop :sites, _Nilable(_Array(::ExternalSite)), default: nil

# ❌ DON'T — `_Any` accepts anything, including nil, and fails
# silently with a NoMethodError two methods later
prop :consensus, _Nilable(_Any), default: nil
prop :siblings, _Array(_Any), default: -> { [] }
prop :sites, _Nilable(_Any), default: nil
```

Use `_Any` only when the arg genuinely can be any type and the
view has explicit polymorphic handling for each shape
(e.g. `Components::InlineModLinks#target` — different classes go
through different `case`-branches). If you find yourself
reaching for `_Any` to silence a typecheck error, the answer is
almost always to figure out the right concrete type instead.

## ALWAYS convert `assert_template` to a CSS-identifier assertion

`assert_template("foo/show/_bar")` only works for ERB partials —
Phlex components / views are rendered directly via `render(...)`,
not through ActionView's template-lookup machinery, so the
assertion will *always* fail after the conversion. **Do not
delete or comment out** the assertion when this happens — that
silently drops the coverage. Instead, replace it with an
`assert_select` (controller tests) or `assert_html` (component
tests) against a CSS selector that proves the same content
rendered:

```ruby
# Before — partial-template assertion
assert_template("observations/show/_thumbnail_map")

# After — assert the panel's stable ID rendered
assert_select("#observation_thumbnail_map")
```

Prefer a stable ID (`id="observation_thumbnail_map"`) when the
panel has one; otherwise an identifier class
(`.show_images`, `.observation_collection_numbers`); as a last
resort, an unambiguous descendant selector. The goal is to pin
the rendered DOM identity — the same thing the template
assertion was implicitly checking when ActionView resolved the
partial.

This rule was added after the obs-show partials sweep dropped a
batch of `assert_template` calls without replacing them — the
tests passed but no longer verified the panel rendered at all.
Re-deriving the coverage from the rendered HTML is the contract;
the partial path was an implementation detail.

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

**Reusable Bootstrap components are a Phlex goal in this codebase.**
One of the reasons we moved to Phlex is to grow a library of
reusable Bootstrap building blocks — `Components::Table`,
`Components::Panel`, `Components::CrudButton::*`, `Components::Modal`,
`Components::NavTabs`, etc. — so that the next view doesn't reach
for raw `<ul class="nav nav-tabs">` / `<table>` / `<div class="panel">`
markup. If a view uses a recognizable Bootstrap pattern (nav-tabs,
panel, button group, modal, table, alert, breadcrumb, badge,
progress bar, pagination strip — basically anything from
[the Bootstrap component docs](https://getbootstrap.com/docs/3.4/components/))
and there's no component for it yet, **extract one** as part of the
conversion, even if there's only one caller right now. The next
view that needs the same pattern shouldn't have to copy markup; it
should reach for `render(Components::TheThing.new(...))` and have
the Bootstrap classes / structure already baked in.

Conversely, if a component already exists for the Bootstrap
pattern you're rendering (`Components::Table`, `Components::Panel`,
`Components::CrudButton::*`, etc.), use it rather than hand-rolling
the markup — see the Tables / Tabs / etc. sections below for the
specific guidance and component APIs.

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

## Action-template + sub-partial organization

An action template (`show.html.erb`, `new.html.erb`,
`edit.html.erb`, …) usually has several sub-partials it composes
(`_some_panel.erb`, `_some_row.erb`, …). When Phlexifying:

- **Action template becomes a class** at `app/views/controllers/
  <controller>/<action>.rb`, named `Views::Controllers::<C>::<A>`.
  That's the class the controller renders.
- **Sub-partials become sibling classes under the same action
  namespace**, file-wise nested in `app/views/controllers/
  <controller>/<action>/<name>.rb`, class-wise
  `Views::Controllers::<C>::<A>::<Name>`.

The action class and its sub-partial classes live in the **same
constant** (the action is both a class AND a namespace — Ruby
allows nested constants under a class just as under a module).
File layout:

```
app/views/controllers/observations/
  show.rb                          # class Views::Controllers::Observations::Show
  show/
    observation_details_panel.rb   # class Show::ObservationDetailsPanel
    name_info_panel.rb             # class Show::NameInfoPanel
    collection_numbers_panel.rb    # class Show::CollectionNumbersPanel
    sibling_records.rb             # module Show::SiblingRecords (mixin)
    …
```

Zeitwerk handles this fine: when the action class is referenced,
it autoloads `show.rb`; when a sub-partial constant is
referenced (`Show::FooPanel`), it autoloads the file under
`show/`. The action class doesn't need to declare any of the
sub-partials — they're discovered by the autoloader on demand.

When the action class renders a sub-partial, qualify the
constant from the namespace root the first time it's referenced
inside another sub-partial:

```ruby
# In Show::ObservationDetailsPanel:
render(Views::Controllers::Observations::Show::CollectionNumbersPanel.new(...))
```

The bare `CollectionNumbersPanel` form would resolve via Ruby's
lexical scope from `Show::ObservationDetailsPanel`, but
Zeitwerk's autoload-on-undefined-constant doesn't fire on
unqualified references inside another constant's body —
preferring the qualified form keeps things robust.

Reference: `Views::Controllers::SpeciesLists::Show` and its
siblings (`SpeciesLists::Details`, `SpeciesLists::Listing`,
`SpeciesLists::Observation`) are the older pattern where
sub-classes are flat siblings of the action class rather than
nested under it; that's also valid, but for **action-specific**
sub-partials (the obs-show case), nesting under the action
class keeps the directory structure mirroring the ERB partial
layout and makes the "which page does this belong to?" question
trivial from the constant name alone.

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

- Field is on the model / FormObject? → `text_field(:foo)` (Symbol,
  model-bound).
- Field's `name=` belongs in the form's namespace but value comes from
  outside the model? → `text_field(:foo, value: …)` (Symbol + explicit
  `value:`).
- Field's `name=` is under a different namespace or top-level? →
  `text_field("namespace[foo]", value: …)` (String, raw `name=`).
- Outside a form? → `Components::ApplicationForm::FieldProxy.new(...) +
  render(Components::ApplicationForm::TextField.new(proxy, ...))` —
  used by feedback / editor components that don't own the `<form>` tag.
- **Never** emit raw `input`, `select`, `textarea`, or `option` tags from a
  form component. If you find yourself reaching for them, you're missing
  one of the four paths above. Re-read the FieldProxy section in
  `phlex_style_guide.md` before proceeding. (This rule was added after PR
  #4224 had to undo a hand-rolled radio group from PR #4076. The
  Symbol+`value:` and String paths landed in PRs #4382 and #4384 to make
  non-model-bound fields go through the same helpers.)

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

   **This is mandatory for every ERB → Phlex conversion** — modals,
   forms, partials, action templates, all of them. Selector-based
   component tests pass with either markup; only a literal HTML diff
   catches whitespace/attribute/wrapper drift that bites users in the
   browser. No skimping.

   **Ordering**: write and pass the parity test BEFORE deleting the
   ERB. The harness has to render the ERB partial via
   `controller.view_context.render(partial: "foo/bar")`, which
   needs the file on disk. Convert → parity test → confirm green
   → delete ERB. Never delete first.

   For the diff harness in this codebase: the test controller used by
   `ComponentTestCase` doesn't inherit `ApplicationController`'s
   `append_view_path Rails.root.join("app/views/controllers")`, so a
   parity test that renders an ERB partial via `view_context.render(
   partial: "foo/bar")` needs to add that path itself, e.g. in
   `setup` (or use `view_paths.unshift(...)`). Without it,
   `ActionView::MissingTemplate` fires for paths under
   `app/views/controllers/`.

## Tables in Phlex views: try `Components::Table` first

Before reaching for `table { thead { tr { ... } }; tbody { @rows.each { ... } } }` in a Phlex view, check whether `Components::Table` fits. It keeps Bootstrap table markup consistent, supports per-column `class:` + arbitrary HTML attrs (`width:`, `data:`, etc.) via `t.column(header, **attrs) { |row| cell }`, and reads more clearly than hand-rolled rows.

### Column mode (uniform rows — the common case)

```ruby
render(Components::Table.new(@users,
                             class: "table-striped my-table")) do |t|
  t.column(:NAME.t) { |u| link_to(u.login, u) }
  t.column(:ROLE.t, class: "text-center") { |u| u.role }
  t.column(:ACTIONS.t, width: "100") { |u| destroy_button(target: u) }
end
```

Per-column `class:` / arbitrary attrs land on both the `<th>` and `<td>` of that column.

### Row mode (Stimulus-rooted rows, Superform `namespace(idx)`, etc.)

When each `<tr>` needs its own data attributes — most commonly because the row IS a Phlex component that emits its own `<tr id="..." data-controller="...">`, or because each row needs Superform's `namespace(idx)` wrapping to scope its field names — use row mode: define columns for the header only (no content block), then provide a single `t.row { |row, idx| ... }` block that renders the whole `<tr>`.

```ruby
render(Components::Table.new(@trackers,
                             tbody_id: "field_slip_job_trackers")) do |t|
  t.column(:FILENAME.t, scope: "col")
  t.column(:STATUS.t,   scope: "col", class: "text-right")
  t.row { |tracker| render(TrackerRow.new(tracker: tracker, user: @user)) }
end
```

`tbody_id:` puts an `id=` on the `<tbody>` (use this when the tbody is a Turbo Stream target — `turbo_stream.prepend(:field_slip_job_trackers) { ... }` to append a new row from an action response).

The row block runs in the caller's closure, so anything in scope at the render site is reachable inside the block — including methods on the form this table happens to be nested inside (e.g. Superform's `namespace(idx)`).

### Skip `Components::Table` (with a `# NOTE:` comment explaining why) when the table needs:

- **Multiple `<tbody>` elements** — e.g. one tbody per group, with sub-rows in a separate `tbody.collapse` (Bootstrap accordion-in-table). Components::Table's single-tbody model can't express this.
- **Stimulus / Turbo data attrs on the `<table>` tag itself** — `<table data-controller="name-list" ...>` with table-level wiring. (Currently `Components::Table` doesn't forward arbitrary attrs to the `<table>`; a small extension would unlock this case.)
- **Mixed-shape rows that don't share an iteration source** — e.g. one row per existing group + N blank "write-in" rows. Row mode handles mixed shapes when they share a row sequence, but two different sources of rows is awkward.
- **A table that isn't really "rows of data"** — e.g. a 3-column layout shell wrapping unrelated panels with a `colspan` footer. Components::Table's purpose is rows of data; bending it elsewhere creates worse abstractions than `table { ... }` directly.

If you find yourself wanting a feature Components::Table doesn't have, prefer adding a small primitive to the component (the `tbody_id:` kind of thing) over a one-off escape hatch in your view. Anything more invasive — multi-tbody support, table-level Stimulus rooting — is a real design discussion, not a quick add.

`Components::Table` is at `app/components/table.rb`; tests in `test/components/table_test.rb`.

## Addendum: No Phlex view resolver

When converting an action template (ERB → `Views::Controllers::<Foo>::<Action>`),
the controller's implicit `render(:new)` must be changed to an explicit
`render(Views::Controllers::<Foo>::New.new(...))`. There is no
"resolver" wired into MO that lets `render(:new)` find a Phlex class
automatically — you have to point at the class and pass props.

The `phlex-rails` gem at version 2.4.0 (MO's installed version)
ships no `Phlex::Rails::Resolver` — zero references to "Resolver" in
either `phlex` or `phlex-rails`. The auto-ivar-copying pattern some
older Phlex 1.x guides describe was never part of the 2.x gem.
Hand-rolling one is possible (custom `ActionView::Resolver` reading
`controller.view_assigns`), but the ivar-push mechanism conflicts
with MO's `prop :foo, Literal::…` convention — bare ivars arrive
without prop declarations, lose type validation, and break the
explicit-prop test ergonomics every existing Phlex view in MO
depends on. The per-conversion cost of "explicit `render(…)`" is
one or two lines in the controller; net win is small and would
fragment the codebase across two render styles.

**Convention**: every action-template conversion changes the
controller to `render(Views::Controllers::<Foo>::<Action>.new(
attr: @ivar, …))`, lifting the ERB-era ivars into explicit props on
the new class. See any existing `app/views/controllers/**/<action>.rb`
for examples.
