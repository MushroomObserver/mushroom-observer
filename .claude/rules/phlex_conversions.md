---
paths: app/components/**/*.rb, app/views/**/*.rb
---

# Phlex Views & Components


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


## Decide first: reusable or single-use?

The first decision when writing a new Phlex class is **where it lives**.
Make this decision before writing any code — it determines the namespace,
the file path, the test location, and how reviewers reason about reuse.

**Default placement: single-use views go in `app/views/controllers/`.**
Page-specific classes — forms, tables, panels, sidebars, navs, modals,
headers, page wrappers, footers, list rows — belong under
`app/views/controllers/<controller>/<name>.rb`. The default is the views
tree, not `app/components/`.

**Exception: true UI primitives.** A genuine, reusable UI building block
— a button group, a badge, an alert, a generic widget recognizable as a
"component" regardless of where it's rendered — can live in
`app/components/` even if only one caller currently exists. The
"speculated future caller" carve-out applies *only* to
recognizably-generic UI primitives, not to page-specific fragments
wearing component clothing (e.g. a `Components::WhateverShowDetails`
that only ever renders one controller's show page — that's a view).

**Reusable Bootstrap components are a Phlex goal in this codebase.**
We're growing a library of reusable Bootstrap building blocks —
`Components::Table`, `Components::Panel`, `Components::CrudButton::*`,
`Components::Modal`, `Components::NavTabs`, etc. — so the next view
doesn't reach for raw `<ul class="nav nav-tabs">` / `<table>` /
`<div class="panel">` markup. If a view uses a recognizable Bootstrap
pattern (nav-tabs, panel, button group, modal, table, alert, breadcrumb,
badge, progress bar, pagination strip) and there's no component for it
yet, **extract one**, even if only one caller exists right now.

Conversely, if a component already exists for the Bootstrap pattern
you're rendering, use it rather than hand-rolling the markup.

Heuristic: would a reader unfamiliar with this codebase look at the
class name and say "yes, that's a component"? If yes, `app/components/`.
If they'd say "that's the `whatever_controller`'s `show` page",
`app/views/controllers/`.

- **Single-use view** →
  `app/views/controllers/<controller>/<name>.rb`, class
  `Views::Controllers::<Controller>::<Name>`, tests in
  `test/views/controllers/...`. Use this when the class only renders
  for one controller's pages, including when the only second caller is
  a turbo_stream response in that same controller.

- **Reusable component** →
  `app/components/<name>.rb`, class `Components::<Name>`,
  tests in `test/components/`. Use this for true UI building blocks
  regardless of current caller count, OR for non-primitive classes
  that already have a concrete second caller.

Both inherit from `Phlex::HTML` via `Components::Base` (`Views::Base` is
a thin subclass). The split is for organization and intent, not
capability — they can do the same things.

If a single-use class becomes reusable later, move it: rename file,
flatten namespace, update callers. Don't speculatively put a single-use
class in `app/components/` "just in case."

Example of the single-use pattern: see
`app/views/controllers/account/api_keys/table.rb`
(`Views::Controllers::Account::APIKeys::Table`) — the api_keys index
table chunk, rendered by both the index page and the post-CUD
turbo_stream response, both within the api_keys controller.

## Action-template + sub-view organization

An action view (`Show`, `New`, `Edit`, …) often composes several
sub-views (`SomePanel`, `SomeRow`, …). Structure them like this:

- **Action view is a class** at `app/views/controllers/
  <controller>/<action>.rb`, named `Views::Controllers::<C>::<A>`.
  That's the class the controller renders.
- **Sub-views are sibling classes under the same action namespace**,
  file-wise nested in `app/views/controllers/<controller>/<action>/
  <name>.rb`, class-wise `Views::Controllers::<C>::<A>::<Name>`.

The action class and its sub-views live in the **same constant**
(the action is both a class AND a namespace — Ruby allows nested
constants under a class just as under a module). File layout:

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
it autoloads `show.rb`; when a sub-view constant is referenced
(`Show::FooPanel`), it autoloads the file under `show/`. The action
class doesn't need to declare any of the sub-views — they're
discovered by the autoloader on demand.

When an action class renders a sub-view, qualify the constant from
the namespace root when referencing it inside another sub-view:

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
`SpeciesLists::Observation`) use the older flat-sibling pattern
where sub-views sit alongside the action class rather than nested
under it; that's also valid, but nesting under the action class
makes the "which page does this belong to?" question trivial from
the constant name alone.

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
6. **When refactoring an existing Phlex component or template, run an
   HTML-parity diff against the pre-refactor output before opening the
   PR.** Use the diff harness pattern from `.claude/rules/testing.md`
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

   Selector-based component tests pass with either markup; only a
   literal HTML diff catches whitespace/attribute/wrapper drift that
   bites users in the browser.

### Parity-harness patterns

The canonical parity test for a Phlex refactor is a one-off
`ComponentTestCase` subclass that renders both the old and new
versions with identical inputs and calls
`assert_html_element_equivalent`. Keep a renamed `_Old` copy of
the original component on the branch for the duration of the
test, then delete it once the refactor is confirmed green.

**1. The controller has no `session` store:**

`ComponentTestCase` disables sessions, but some helpers read
`controller.session`. Stub it on the controller:

```ruby
session = { search_type: "observations", pattern: "Boletus" }
controller.define_singleton_method(:session) { session }
```

**2. Page-chrome helpers that crash in the test environment
(`add_index_title`, `add_project_banner`, etc.):**

Those helpers only side-effect `content_for` buffers — they
contribute nothing to the fragment the parity test is comparing.
Prepend a no-op stub onto the helper modules at load time:

```ruby
module ChromeStubsForFooParity
  STUBS = {
    Header::TitleHelper => [:add_index_title],
    Header::ContextNavHelper => [:add_context_nav],
    Header::IndexPaginationHelper => [:add_pagination],
    ProjectsHelper => [:add_project_banner],
    ApplicationHelper => [:container_class]
  }.freeze

  STUBS.each do |host, methods|
    mod = Module.new do
      methods.each { |m| define_method(m) { |*, **| nil } }
    end
    host.prepend(mod)
  end
end
```

(Stub on the helper module — not on `view_context` or
`ActionView::Base` — because Rails resolves helpers through the
included-module chain and a singleton-method or
`prepend(ActionView::Base)` doesn't reliably win.)

**3. Comparing output that includes a `<form>`:**

Superform's `form-group` / `<label>` auto-wraps and its always-
emitted `authenticity_token` / `_method` hidden inputs can differ
between implementations — comparing them strictly will fail.
Two options:

- **Skip the form**: strip the `<form>` element from both
  sides before comparing, then pin the surrounding chrome:

  ```ruby
  def strip_form(html)
    frag = Nokogiri::HTML5.fragment(html)
    frag.css("form").remove
    frag.to_html
  end

  old_html = strip_form(render(FooOld.new(...)))
  new_html = strip_form(render(Foo.new(...)))
  assert_html_element_equivalent(
    "<div id='parity'>#{old_html}</div>",
    "<div id='parity'>#{new_html}</div>",
    selector: "#parity",
    label: "page_minus_form"
  )
  ```

- **Compare the form too**: pass `label: false` on every Phlex
  field helper (`text_field(:foo, label: false)`) to skip the
  `form-group` wrap + auto-label, and lean on
  `ComponentTestCase#strip_form_implementation_noise!` to drop
  the `utf8` / `authenticity_token` / `_method` hidden inputs
  (the helper does this automatically when `strip_csrf: true`,
  the default).

**4. Wrapping a body fragment for comparison:**

When the parity surface is "the whole rendered output," wrap
both sides in a `<div id="parity">` shell and pin that:

```ruby
assert_html_element_equivalent(
  "<div id='parity'>#{old_html}</div>",
  "<div id='parity'>#{new_html}</div>",
  selector: "#parity",
  label: "whole_page"
)
```

The helper anchors on the first `#parity` element in each
fragment and walks the entire subtree.

**5. Delete the `_Old` copy and the parity test together.**

Once the refactor is confirmed green, remove both the `_Old`
class file and the parity test in the same commit.

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

