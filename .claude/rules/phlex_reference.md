---
paths: app/components/**/*.rb, app/views/**/*.rb
---

# Phlex Reference

Phlex component conventions, Kit syntax, Superform usage, and component
architecture. This is the single reference for Phlex. For general Ruby style,
see `.claude/ruby_style_guide.md`. For test structure and assertion patterns,
see `.claude/rules/testing.md`.

MO's web views are fully converted to Phlex — there is no ERB left under
`app/views/`. (Action Mailer templates under `app/views/mailers/` still use
ERB; that's a separate, unconverted concern this doc doesn't cover.)

## Kit syntax — what has it, what doesn't

**Only `Components` extends `Phlex::Kit`.** `Views` deliberately does not
(see `config/initializers/phlex.rb`).

`Phlex::Kit` generates a bare, callable method for every class sitting
**directly** under the extending namespace. `Components::Icon` gets an
`Icon(...)` method; `Components::Link` gets `Link(...)`. Calling that
method **replaces both** the `render(...)` call and the `.new(...)` call
in one shot:

```ruby
# Good — Kit syntax
Icon(type: :edit)

# Equivalent, but never write this once Kit sugar exists —
# it's strictly more to type for the same effect
render(Components::Icon.new(type: :edit))
```

**Kit sugar only fires for classes exactly one level under `Components`.**
`Components::Link::Get`, `Components::ListGroup::Item`,
`Components::Help::Block` — anything nested one level deeper — never
gets a bare method, no matter how deep the rest of the app's Kit adoption
goes. This is a phlex-rails limitation, not an MO oversight (see
[issue #316](https://github.com/yippee-fun/phlex-rails/issues/316)).

**`Views` never extends `Phlex::Kit`, and that's intentional, not a gap.**
Every real view lives 2+ levels deep under `Views`
(`Views::Controllers::<Controller>::<Action>`, see "Action-template +
sub-view organization" below) — Kit sugar only ever fires for classes
one level under the extending namespace, so extending `Views` would add
a dead `extend` with no caller ever able to use it. The only classes
directly under `Views` are abstract bases (`Views::Base`,
`Views::FullPageBase`) that are never rendered directly. Views are always
reached via `render(Views::Controllers::<C>::<A>.new(...))` or, from a
sibling under the same action namespace, an unqualified reference (see
"Collapse deep namespaces" below) — never Kit syntax.

**What to do with a nested class depends on whether it has a dispatching
parent:**

- **Nested component with a dispatching parent** — `Components::Link::Get`,
  `Components::Button::Delete` — reach it through the parent's Kit-sugar
  dispatch (`Link(type: :get, ...)`, `Button(type: :delete, ...)`), never
  by calling the nested class directly, even though
  `render(Components::Link::Get.new(...))` is technically possible.
- **Nested component with no dispatching parent** — a genuine sibling
  grouping, not a "variant" of one root type (e.g.
  `Components::ListGroup::Item` next to `Components::ListGroup::LinkItem`)
  — needs the full `render(Components::ListGroup::Item.new(...))` form.
  (`ListGroup`'s own methods can reference `Item`/`LinkItem` unqualified
  via ordinary Ruby lexical constant lookup — that's a different
  mechanism from Kit sugar and only works from inside `ListGroup` itself.)
- **Nested view** (`Views::Controllers::<C>::<A>::<SubView>`) — no Kit
  sugar, no dispatcher either way — full namespace + `render()` is the
  only way to call it.

```ruby
# Good — top-level component, Kit syntax
Icon(type: :edit)
Link(type: :active, content: title, path: url)

# Good — nested component reached through its dispatching parent
Link(type: :get, name: "Show", target: url)

# Good — nested view, no Kit sugar exists, no dispatcher
render(Views::Controllers::Observations::Show::CollectionNumbersPanel.new(
  obs: @obs, user: @user
))

# Bad — verbose full-namespace render() for something with Kit sugar
render(Components::Icon.new(type: :edit))
render(Components::Link::Get.new(name: "Show", target: url))
```

### Writing a new dispatcher component

`Components::Link`, `Components::Button`, and `Components::Help` share one
pattern: a `DISPATCH` hash mapping `type:` symbols to subclass names, and
a `self.new` override that routes to the matching subclass:

```ruby
class Components::Widget < Components::Base
  DISPATCH = { foo: :Foo, bar: :Bar }.freeze

  def self.new(**kwargs, &block)
    type_sym = kwargs[:type]&.to_sym
    if (klass_name = DISPATCH[type_sym])
      kwargs.delete(:type)
      return const_get(klass_name).new(**kwargs, &block)
    end

    if kwargs.key?(:type)
      raise(ArgumentError.new(
              "Unknown Widget type: #{kwargs[:type].inspect}. " \
              "Valid types: #{DISPATCH.keys.join(", ")}."
            ))
    end

    super
  end
end
```

`Link`, `Button`, and `Help` all treat a missing `type:` as their own
plain variant (falls through to `super`, a real instance of the
dispatcher class itself) — `Help` with no `type:` is the plain
`help-block` shape; only genuinely distinct DOM shapes (`:tooltip`,
`:collapse_block`, `:collapse_info_trigger`) get routed to a subclass.

Keep every dispatched subclass pure-kwargs (no positional-arg
shorthand) so `self.new(**kwargs, &block)` needs no `*args`
passthrough. `Components::Help::Block` / `Help::Note` (now merged into
`Components::Help`) used to accept a legacy `(element, string)`
positional pair — an ERB-helper holdover — which forced the dispatcher
to forward `*args` too. Dropping the positional form when the merge
happened let the dispatcher shrink back to the plain `Link`/`Button`
shape.

### Kit sugar doesn't reach `app/components/application_form/*`

Every class under `app/components/application_form/` — `DateField`,
`TextField`, `CheckboxField`, `SelectField`, etc. — extends `Phlex::HTML`
directly rather than existing as its own `Components::<Name>` constant.
Calling Kit sugar (`Help(...)`, `Icon(...)`, etc.) from inside one of
these classes (or a module mixed into them, like `FieldWithHelp`) raises
`NoMethodError: undefined method 'Help' for an instance of
Components::ApplicationForm::DateField` — not a typo, a structural gap.

**Why**: Phlex::Kit's sugar is wired up by a `const_added` hook that
fires on `Components` itself. When a class is assigned directly as
`Components::Foo`, the hook mixes a shared module (call it `Components`
again — it's the same namespace module) into `Foo`, and separately
defines an instance method named `Foo` *on that shared module* for
every other Kit-registered sibling to call. `const_added` only
re-fires on *nested modules* (`when Module; constant.extend(Phlex::Kit)`
in the gem source) — never on nested *classes*. `Components::ApplicationForm`
is a class (`class Components::ApplicationForm < Superform::Rails::Form`),
so defining `DateField` inside it never triggers the hook, regardless of
what `DateField` itself inherits from.

**Fix**: `include ::Components` into a module that's already mixed into
every field class that needs it. `FieldWithHelp` is included by every
concrete field class (`DateField`, `TextField`, `CheckboxField`,
`ReadOnlyField`, `SelectField`, `StaticTextField`, `TextareaField`), so
adding `include ::Components` there — see `app/components/application_form/
field_with_help.rb` — restores Kit sugar transitively for all of them:
Ruby's module inclusion carries `Components`'s accumulated instance
methods (and its `Phlex::Kit::LazyLoader` `method_missing` fallback)
along the whole include chain. Without a shared mixin to hang it on,
fall back to the full `render(Components::Help.new(...))` form instead
— it works everywhere, unconditionally.

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

**This isn't just an autoload nicety — the compact `class A::B::C`
definition form actively breaks bare references to flat siblings.**
`class Views::Controllers::Observations::Search::Show < Views::Base`
only puts `Show` itself into `Module.nesting` — NOT `Search` or
`Observations`. A bare `Help.new` inside that class's `view_template`
will *not* find a flat sibling `Views::Controllers::Observations::
Search::Help`, because `Search` was never lexically opened. Ruby then
falls through the ancestor chain to the top level and may silently
resolve to an unrelated same-named constant elsewhere in the app
(e.g. `Components::Help`) instead of raising — a wrong-class bug, not
a load error, so it can hide until the code path is actually exercised.
Always qualify fully: `Views::Controllers::Observations::Search::Help.new`.
The fully-expanded `module Views::Controllers::Observations; module
Search; class Show; ...; end; end; end` form (or nesting `Show` inside an
explicitly-opened `module ...::Search`) does add `Search` to
`Module.nesting` and avoids the trap, but explicit full qualification is
the safer default regardless of which class-definition form is in play.

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

Note the caveat above, though: this unqualified-sibling shorthand
depends on the enclosing namespaces actually being part of
`Module.nesting` at the reference site. The `module X::Y; class Z; ...`
compact-module form (used here) keeps `X::Y` in nesting. The *compact
class* form (`class X::Y::Z < Base`) does not — see "Action-template +
sub-view organization" above for the trap that creates.

## Multiple anonymous stub Phlex views in one test file — name them

When a test needs more than one throwaway Phlex view to prove a
component behaves correctly when called from a "real" view context
(not just `render(Component.new(...)) { ... }` at the test's own top
level), don't define them via `Class.new(Components::Base) do ... end`
more than once in the same file. `test/classes/localization_files_test.rb`
(`test_find_missing_tags_and_duplicate_method_defs`) scans every source
file for duplicate `def` names using an indentation-based `class`/
`module` scope tracker — it has no concept of a `Class.new do ... end`
block as its own scope. Two anonymous stubs each defining `def
view_template` in the same file collide as a false "duplicate method
definition" from the scanner's point of view, even though they're
genuinely separate Ruby closures.

```ruby
# ❌ Trips the duplicate-def scanner the second time this shape
# appears in one file — the scanner doesn't scope `Class.new do...end`
def test_one
  stub_view = Class.new(Components::Base) do
    def view_template
      ...
    end
  end
end

def test_two
  stub_view = Class.new(Components::Base) do
    def view_template   # ← flagged as a duplicate of the one above
      ...
    end
  end
end

# ✅ Named nested classes — the scanner's class/end indentation
# tracking sees each as its own scope
class ListGroupTest < ComponentTestCase
  class StubViewOne < Components::Base
    def view_template
      ...
    end
  end

  class StubViewTwo < Components::Base
    def view_template
      ...
    end
  end
end
```

See `test/views/controllers/comments/index_test.rb`
(`LegacyCommentList` / `NewCommentList`, nested inside `IndexTest`)
for the established pattern.

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
falls into the move-vs-register decision above.

## Component Style

### Accessing Literal Properties

**IMPORTANT**: Literal::Properties must be accessed as instance variables, not as method calls.

```ruby
class Components::Example < Components::Base
  prop :user, _Nilable(User)
  prop :cached, _Boolean, default: false

  def view_template
    # Good - access as instance variable
    return unless @user
    if @cached
      # ...
    end

    # Bad - will cause "undefined local variable or method" error
    return unless user
    if cached
      # ...
    end
  end
end
```

### HTML Helpers

**Use Phlex's native HTML helpers**, never `view_context.tag` or Rails
`tag`/`content_tag` helpers wrapped in `unsafe_raw`.

```ruby
# Good - native Phlex
def view_template
  div(class: "container", id: "main") do
    h1("Title")
    p(class: "description") { plain("Some text") }
  end
end

# Bad - Rails tag helpers / view_context
def view_template
  view_context.tag.div(class: "container", id: "main") do
    view_context.tag.h1("Title")
  end
end
```

### HTML Element Syntax

**Empty Elements**: Don't pass empty strings to Phlex HTML elements.

```ruby
# Good
div(class: "clearfix")
span(class: "badge")

# Bad
div("", class: "clearfix")
span("", class: "badge")
```

### Phlex `option()` Element

Phlex's `option()` does not accept a positional text argument. Use the block
form to set the display text.

```ruby
# Good
option(value: "clade") { "Clade" }

# Bad - wrong number of arguments error
option("Clade", value: "clade")
```

### Prefer Phlex Methods Over ActionView Helpers

When possible, use native Phlex HTML methods instead of Rails ActionView tag helpers. Phlex methods are more idiomatic and don't require extra includes.

#### Labels:
```ruby
# Avoid - requires include Phlex::Rails::Helpers::LabelTag
include Phlex::Rails::Helpers::LabelTag
label_tag(:field_name, class: "label-class", data: { ... })

# Prefer - native Phlex method
label(for: "field_name", class: "label-class", data: { ... }) { "Label text" }
```

#### Buttons:
```ruby
# Avoid - requires include Phlex::Rails::Helpers::ButtonTag
include Phlex::Rails::Helpers::ButtonTag
button_tag("Click me", type: "button", class: "btn")

# Prefer - native Phlex method
button(type: "button", class: "btn") { "Click me" }
```

#### Divs, Spans, etc:
```ruby
# Always use native Phlex methods
div(class: "container") { "Content" }
span(class: "badge") { "New" }
p(class: "text") { "Paragraph" }
```

#### Links:
```ruby
# Good - native Phlex
a(href: user_path(@user)) { "View User" }

# Avoid - Rails helper
link_to("View User", user_path(@user))
```

#### When to use Rails helpers:
- For `button_to` (has complex behavior with no Phlex equivalent)
- For helpers that don't have Phlex equivalents
- Never use `form_with` or `fields_for` — use Superform and FieldProxy instead

### Rendering Content

**Use Phlex rendering methods** for outputting content:
- `plain(text)` - for plain text
- `whitespace` - for spacing between elements
- `trusted_html(html)` - for HTML-safe strings (ActiveSupport::SafeBuffer) from Rails helpers

**NEVER use `raw()`** - use `trusted_html()` instead.

```ruby
# Good - using trusted_html for HTML-safe content
def view_template
  div do
    trusted_html(name.display_name.t)  # .t returns ActiveSupport::SafeBuffer
  end
end

# Good - plain content rendering
def view_template
  div do
    plain("Hello ")
    b("World")
    whitespace
    plain("!")
  end
end

# Bad - using raw() for any content
def view_template
  div do
    raw(name.display_name.t)  # Use trusted_html instead
  end
end

# Bad - using safe_join or building arrays
def view_template
  div do
    raw(safe_join(["Hello ", tag.b("World"), "!"]))
  end
end
```

**Why trusted_html?**
- `trusted_html()` is defined in `Components::Base` specifically for HTML-safe content
- It handles `ActiveSupport::SafeBuffer` correctly without requiring `rubocop:disable`
- Rails translation methods (`.t`, `.l`) return HTML-safe strings that should use `trusted_html`
- Only when you trust the content (never for user input)

**When NOT to use `trusted_html()`:**
- For rendering components - use `render(component)` instead
- For registered output helpers - they already return safe HTML
- For Phlex HTML methods - they handle safety automatically

### Using `plain()` vs Direct Output

**CRITICAL**: Understand when to use `plain()` and when to output values directly.

#### The Rule:
- `plain()` **always escapes** HTML, even if the string is marked `html_safe?`
- Direct output (without `plain()`) **respects the `html_safe?` flag**

#### Examples:
```ruby
# For plain text (no HTML tags)
plain("Some plain text")
plain("User: #{@user.name}")

# For HTML-safe strings (from helpers, formatted text, etc.)
# Good - output directly
@obs.user_format_name(@user).t.small_author
location_link(@where, @location)
some_helper_that_returns_html

# Bad - will double-escape HTML
plain(@obs.user_format_name(@user).t.small_author)  # Produces &lt;b&gt;&lt;i&gt;Name&lt;/i&gt;&lt;/b&gt;
```

#### When to use `plain()`:
- For literal strings without HTML
- For interpolated text that should be escaped
- For user-generated content that must be sanitized

#### When to output directly (no `plain()`):
- For registered output helpers (must be registered with `mark_safe: true`)
- For Rails helper methods that return HTML (`button_to`, etc.)
- For formatted text methods that return HTML (`.t`, `.tpl`, etc.)
- For any string already marked `.html_safe`

Calling **view_context** is nearly always a code smell that you should find a
native Phlex method or include the method as an output_helper or value_helper.

```ruby
# Good
def form_action
  observation_view_path(id: @obs_id)
end

# Bad - Rails path helpers are already available within Phlex
def form_action
  view_context.observation_view_path(id: @obs_id)
end
```

### Including Rails Built-in Helpers

Rails helpers are available as Phlex modules under `Phlex::Rails::Helpers`. The module name matches the helper method name in PascalCase. **Only use these when Phlex has no native equivalent.**

#### Examples:
```ruby
class Components::MyComponent < Components::Base
  include Phlex::Rails::Helpers::ButtonTo    # for button_to (no Phlex equivalent)
  include Phlex::Rails::Helpers::ClassNames  # for class_names
end
```

After including the module, call the helper directly without any prefix:
```ruby
button_to(some_path, method: :delete)
```

**Prefer Phlex native helpers when possible:**
```ruby
# Good - Use Phlex's native helpers
a(href: some_path) { "Click me" }       # instead of link_to
img(src: image_url, alt: "Photo")       # instead of image_tag

# Avoid - Don't use Rails helpers when Phlex has equivalents
link_to("Click me", some_path)
image_tag("photo.jpg", alt: "Photo")
```

**NEVER use these helpers** (they have better alternatives):
- `form_with` - Use Superform instead
- `fields_for` - Use Superform's `namespace` or `FieldProxy` instead
- `safe_join` - Use MO's `array.safe_join("joiner")` extension instead

### Registering Custom Application Helpers

Custom helpers from `app/helpers/` should be registered in `app/components/base.rb` so they're available to all components.

#### Registration Types:

1. **Output Helpers** (return HTML) - use `register_output_helper`:
```ruby
register_output_helper :propose_naming_link
register_output_helper :location_link
register_output_helper :modal_link_to
```

2. **Value Helpers** (return values/strings) - use `register_value_helper`:
```ruby
register_value_helper :permission?
register_value_helper :url_for
register_value_helper :image_vote_as_short_string
```

#### Important Rules:

1. **DO NOT register Rails built-in helpers** - use `include Phlex::Rails::Helpers::HelperName` instead.

2. **DO NOT register helpers that accept blocks** - these need special handling and may not work correctly with `register_output_helper`.

3. After registration, call helpers directly without the `helpers.` prefix:
```ruby
# Good
propose_naming_link(@obs.id, context: "lightbox")
location_link(@obs.where, @obs.location)

# Bad
helpers.propose_naming_link(...)
helpers.location_link(...)
```

4. **NEVER use `raw()`** - use MO's `trusted_html()` method instead for HTML strings that need to be rendered unescaped.

See "`register_value_helper` is a code smell" above for when registering a
*new* value helper during a conversion needs the user's explicit sign-off.

### Joining HTML Strings

Use MO's `array.safe_join("joiner")` extension:
```ruby
# Good
fields = [helper1(...), helper2(...), helper3(...)]
fields.safe_join           # joins with empty string
fields.safe_join(", ")     # joins with separator
```

### Converting Hash to URL

```ruby
# Use url_for (if registered as value helper)
image_link = url_for({ controller: :images, action: :show, id: @image.id }.merge(only_path: true))

# Or use normalize_link pattern (in BaseImage):
def normalize_link(link)
  return nil if link.nil?
  return link if link.is_a?(String)
  url_for(link.merge(only_path: true))
end
```

### Phlex Built-in Helpers

Phlex provides useful helper methods for common patterns.

#### `mix` - Merge attribute hashes intelligently

Combines multiple attribute hashes, treating class values as token lists rather
than replacing them. Useful for components that accept user-provided attributes.

```ruby
# Component that accepts additional classes/attributes
def initialize(**attributes)
  @attributes = attributes
end

def view_template
  # User's classes get combined with component's classes
  div(**mix({ class: "card border" }, @attributes)) { yield }
end

# Usage - classes combine: "card border purple-card"
render(Card.new(class: "purple-card"))
```

Use `class!:` (with bang) to override instead of merge:
```ruby
div(**mix({ class: "default" }, { class!: "override" }))
# Result: class="override"
```

#### `grab` - Access reserved Ruby keywords

Extracts keyword arguments whose names are reserved Ruby keywords like `class`,
`if`, `for`, etc.

```ruby
def initialize(class:, if:)
  @class = grab(class:)           # Single value
  @class, @if = grab(class:, if:) # Multiple values as array
end
```

### Iteration

**Render directly while iterating** instead of building arrays and joining.

```ruby
# Good
def render_links
  items.each_with_index do |item, index|
    plain("|") if index > 0
    a(item.name, href: item.path)
  end
end

# Bad
def render_links
  links = items.map do |item|
    helpers.link_to(item.name, item.path)
  end
  raw(safe_join(links, "|"))
end
```

### HTML Helpers in Test Slot Blocks

**IMPORTANT**: When rendering HTML in slot blocks within tests, use `view_context.tag.*` helpers instead of Phlex HTML methods.

#### Why Phlex HTML methods don't work in slot blocks:

Slot blocks (e.g., `panel.with_thumbnail { ... }`) are captured by phlex-slotable and evaluated in the original calling context (test context), not in the Phlex component's rendering context. Phlex HTML methods like `img()`, `div()`, etc. require a Phlex rendering buffer which is not available in test blocks.

#### Examples:

```ruby
# Bad - Phlex HTML methods don't work in slot blocks
render(Components::Panel.new) do |panel|
  panel.with_thumbnail do
    img(src: "/path/to/image.jpg", alt: "Thumbnail")  # NoMethodError!
  end
end

# Good - Use view_context.tag helpers
render(Components::Panel.new) do |panel|
  panel.with_thumbnail do
    view_context.tag.img(
      src: "/path/to/image.jpg",
      alt: "Thumbnail",
      class: "img-thumbnail"
    )
  end
end

# Also correct - Plain HTML strings work
render(Components::Panel.new) do |panel|
  panel.with_thumbnail do
    "<img src=\"/path/to/image.jpg\" alt=\"Thumbnail\">".html_safe
  end
end
```

#### Why view_context.tag works:

1. It's delegated from ComponentTestHelper and available in the test context
2. It uses Rails' built-in tag helpers, not Phlex methods
3. It doesn't depend on the Phlex rendering buffer
4. It works in any context — tests, slot blocks, etc.

**Note**: In actual component code (inside `view_template`), use native Phlex HTML methods like `img()`, `div()`, etc. This pattern is only needed for test slot blocks.

## Rendering Phlex Fragments

**To render specific fragments from a Phlex component**, use the `.call(fragments: [...])` method:

```ruby
Components::ImageInfo.new(
  user: @user,
  image: @image
).call(fragments: ["copyright"])
```

**In the component**, wrap fragment content with `fragment("name")` block:

```ruby
class Components::ImageInfo < Components::Base
  def view_template
    # Full template renders all fragments
    [owner_name, copyright, notes].compact_blank.safe_join
  end

  # Fragment method - wrap content with fragment() to enable selective rendering
  def copyright
    return "" unless @image

    fragment("copyright") do
      div(class: "copyright") { "© #{@image.year}" }
    end
  end

  # Non-fragment method - always rendered when component is rendered
  def owner_name
    div(class: "owner") { @image.owner }
  end
end
```

**Important**:
- Wrap the content you want to be selectively renderable with `fragment("name") do ... end`
- The fragment name passed to `fragment()` must match the name in `.call(fragments: ["name"])`
- Methods not wrapped with `fragment()` will always be rendered

Resources:
- Phlex fragments: https://www.phlex.fun/components/fragments.html

## Fragment Caching in Phlex

**Enable caching** by adding `cache_store` method to `Components::Base`:

```ruby
class Components::Base < Phlex::HTML
  def cache_store
    Rails.cache
  end
end
```

**Use caching** in components:

```ruby
def render_cached_items
  @items.each do |item|
    cache(item) do
      render(ItemComponent.new(item: item))
    end
  end
end
```

**Caching is incompatible with the builder/`vanish` collection pattern.**
A fragment cache HIT skips the cached block entirely and replays stored
HTML — it never re-executes the block. If a component collects child
renders via a builder that registers them into an array and then
`vanish`es the actual block (discarding whatever the block wrote to the
Phlex buffer, e.g. `Components::ListGroup`'s `list.item { ... }` /
`list.empty { ... }` slots), a cache HIT means the registration inside
the block never runs on that request — so nothing after the cache line
knows what to render. Ordinary nested `render(...)` calls that write
straight to the buffer are cache-agnostic and don't have this problem.
When a component needs both patterns (e.g. `ListGroup` items usually
needing the builder pattern for reasons unrelated to caching, but one
item shape being individually cacheable), give the cacheable shape its
own standalone sibling component instead of routing it through the
`vanish`-based builder (see `Components::ListGroup::LinkItem` for the
established example).

Resources:
- Phlex documentation: https://www.phlex.fun/
- Phlex caching: https://www.phlex.fun/components/caching
- Literal properties: https://literal.fun/docs/properties.html

## Form Components (Superform)

**Every form component must extend `Components::ApplicationForm`.** This rule
has no exceptions — it applies to all forms regardless of HTTP method (GET,
POST, PATCH), layout context (navbar, modal, page), or whether the form maps
to a model. Never use `Components::Base` with the raw Phlex `form()` method
for form conversions.

Before writing ANY Phlex form component, you MUST:

1. Read this section in full, plus `app/components/application_form.rb`
   for the base class API, then `app/components/application_form/
   field_helpers.rb` for all available field helpers.
2. Read an existing form component as a reference (e.g.
   `app/components/herbarium_form.rb`, `app/components/name_form.rb`).

Do NOT skip these reads even if the conversion seems straightforward.

`ApplicationForm` inherits from `Superform::Rails::Form`, which creates a
Rails-compliant form tag implicitly via the `around_template` hook. Form
components should therefore never use the Phlex `form` method. They should call
`super do... end` within `view_template`. The template itself should only render
the **contents** of the form.

`ApplicationForm` also provides helper methods for rendering all types of
fields. **Always use these helpers** instead of the verbose
`render(field(...).xxx(...))` pattern or the general Phlex `input` method.

```ruby
# Good - Use helper methods
text_field(:name, label: "Name:", size: 40)
textarea_field(:notes, label: "Notes:", rows: 6)
checkbox_field(:approved, label: "Approved")
radio_field(:status, ["active", "Active"], ["inactive", "Inactive"])
select_field(:rank, rank_options, label: "Rank:")
static_field(:display_name, label: "Name:", value: @model.name, inline: true)
read_only_field(:locked_field, label: "Value:", value: @value)

# Bad - Verbose render(field(...)) pattern
render(field(:name).text(wrapper_options: { label: "Name:" }, size: 40))
render(field(:notes).textarea(wrapper_options: { label: "Notes:" }, rows: 6))
```

### NEVER hand-roll form-control HTML inside a form component

**HARD RULE**: Inside any class that extends `Components::ApplicationForm`, do
NOT emit raw `input`, `select`, `textarea`, or `option` Phlex tags for form
controls. Every form control goes through an `ApplicationForm` field helper
(`text_field`, `textarea_field`, `radio_field`, `checkbox_field`,
`select_field`, `date_field`, `number_field`, `password_field`, `file_field`,
`hidden_field`, `autocompleter_field`, `static_field`, `read_only_field`,
`submit`, `upload_fields`).

The helpers accept the field name as either a Symbol or a String, with three
distinct paths covering every case you'll hit (PRs #4382, #4384):

| First arg | When to use | Example |
|---|---|---|
| **Symbol** | The field IS an attribute of the form's model / FormObject. Value reads from the model. | `text_field(:title)` |
| **Symbol + explicit `value:`** | The field's `name=` belongs in the form's namespace, but the value comes from somewhere other than the model (controller-supplied state, derived value, etc.). Explicit value wins over `model.foo`. | `radio_field(:dates_any, *choices, value: @dates_any)` |
| **String** | The field's `name=` is under a different namespace from the form's model, or a top-level param. Raw `name=` attribute, value from `value:`. | `text_field("member[lat]", value: @member_lat)` `hidden_field("approved_rank", value: x)` |

**Why this rule exists**: The field helpers generate the exact Bootstrap
markup, ARIA attributes, ID/name conventions, and Stimulus hooks the rest of
the app expects. Hand-rolled `input`s skip all of that (rule added after PR
#4224 had to undo hand-rolled radios for a non-model field).

**Decision tree** when adding a field to an `ApplicationForm` subclass:

```
Is the field an attribute of the form's model / FormObject?
├── Yes → `text_field(:foo)` (Symbol, model-bound).
└── No  → does the field's `name=` belong in the form's namespace?
         ├── Yes → `text_field(:foo, value: …)`
         │         (Symbol + value:, name stays namespaced, explicit value).
         └── No  → `text_field("namespace[foo]", value: …)`
                    (String, raw `name=`, explicit value).
                    NEVER hand-roll the HTML.
```

**Reference example** for the non-model-field case (`ProjectForm` —
`dates_any` is UI state, not a `Project` column; the `name=` still belongs
under `project[...]` so the Symbol-with-value form is the right shape):

```ruby
def render_dates_any_radios
  radio_field(:dates_any,
              ["false", range_label],
              ["true", any_label],
              value: @dates_any)
end
```

- **Outside a form?** Use `Components::ApplicationForm::FieldProxy.new(...) +
  render(Components::ApplicationForm::TextField.new(proxy, ...))` — see
  "FieldProxy: Fields Without a Superform Field Backing" below. Used by
  feedback / editor components that don't own the `<form>` tag.
- **Never** emit raw `input`, `select`, `textarea`, or `option` tags from a
  form component. If you find yourself reaching for them, you're missing
  one of the paths above. (This rule was added after PR #4224 had to undo
  a hand-rolled radio group from PR #4076. The Symbol+`value:` and String
  paths landed in PRs #4382 and #4384 to make non-model-bound fields go
  through the same helpers.)

### Pattern B Forms: Internal FormObject Creation

For non-CRUD forms (email forms, action forms), prefer **Pattern B**: the form
component creates its own FormObject internally rather than receiving one.

```ruby
class Components::UserQuestionForm < Components::ApplicationForm
  # Accept optional model arg for ModalForm compatibility (ignored - we create
  # our own FormObject). This is Pattern B: form creates FormObject internally.
  def initialize(_model = nil, target:, subject: nil, message: nil, **)
    @target = target
    form_object = FormObject::UserQuestion.new(
      subject: subject,
      message: message
    )
    super(form_object, **)
  end
end

# View usage - clean kwargs only
render(Components::UserQuestionForm.new(target: @target))
```

**Why `_model = nil`?** ModalForm calls `component_class.new(model, **params)`
with model as the first positional argument. Pattern B forms ignore this model
(they create their own) but accept it for ModalForm compatibility.

**Benefits**:
- Views are clean - just pass domain objects as kwargs
- Form owns its FormObject creation logic
- Works with both direct rendering and ModalForm turbo_stream responses

### Form Inside a Modal

When a Superform is rendered inside a Bootstrap modal, the `<form>` tag's
relationship to `.modal-body` / `.modal-footer` matters. The two options:

| Form shape | What the form owns | Modal slot |
|---|---|---|
| Form has a distinct footer-button row (submit + cancel separated from fields) | Both `.modal-body` AND `.modal-footer` | `:form_content` slot |
| Form is all body content (e.g. one inline submit button below the fields) | Just `.modal-body` (or nothing — Modal renders it) | `:body` slot |

#### Pattern A: form spans `.modal-body` + `.modal-footer` (BS3 footer chrome)

Forms with submit/cancel buttons that should sit in `.modal-footer` (top
border, right alignment, button spacing) must have the `<form>` tag wrap
**both** modal sections, so the submit button in `.modal-footer` is
naturally inside the form. Anything else either drops `.modal-footer`
entirely (and synthesizes ad-hoc `text-right mt-3` chrome — anti-pattern)
or requires HTML5 `form="<id>"` attributes on out-of-form buttons.

To use this pattern:

1. **Declare** the form opts in via a class method:

    ```ruby
    class Components::TrustSettingsForm < Components::ApplicationForm
      # Tells ModalTurboForm (and any Modal caller) to render this form
      # via Modal's :form_content slot, not :body.
      def self.owns_modal_sections?
        true
      end
      # ...
    end
    ```

2. **Emit both divs inside `view_template`**, using Superform's yield so
   the `<form>` opens before `.modal-body` and closes after `.modal-footer`:

    ```ruby
    def view_template
      super do
        hidden_field(:do, value: "add_target_location")
        div(class: "modal-body", id: @body_id) do
          div(id: @flash_id) if @flash_id
          render_fields
        end
        div(class: "modal-footer") { render_footer_buttons }
      end
    end
    ```

3. **Accept `modal_ids: { body:, flash: }`** in the initializer. ModalTurboForm
   passes this automatically when it detects `owns_modal_sections?`. The two ids
   serve different purposes — drop either and you silently break a feature:

    | id | What targets it |
    |---|---|
    | `body_id` | Turbo-stream re-renders that replace `.modal-body` after a server action — without the id, the stream can't find its target. |
    | `flash_id` | `_modal_form_reload.erb` injects in-modal validation flash messages into this slot on submit failure — without the id, validation errors disappear. |

    ```ruby
    def initialize(model, modal_ids: {}, **)
      @body_id  = modal_ids[:body]
      @flash_id = modal_ids[:flash]
      super(model, **)
    end
    ```

4. **Render via Modal's `:form_content` slot** (ModalTurboForm does this
   automatically when `owns_modal_sections?` is true; for direct
   `Components::Modal.new` callers, do it yourself):

    ```ruby
    render(Components::Modal.new(id: "modal_x", title: "Edit", user: @user)) do |m|
      m.with_form_content { render(Components::ThingForm.new(@thing)) }
    end
    ```

#### Pattern B: form lives inside `.modal-body`

When the form has no distinct footer-button row — e.g. a one-button
confirmation form, or fields with an inline submit at the bottom — render
the form via Modal's regular `:body` slot. Don't declare
`owns_modal_sections?`. The form is just content; Modal handles all
chrome around it.

```ruby
render(Components::Modal.new(id: "modal_y", title: "Pick")) do |m|
  m.with_body { render(Components::SimpleForm.new(@thing)) }
end
```

#### Modal Form Anti-Patterns

- **Synthesizing footer chrome inside `.modal-body`.** Don't add a
  `<div class="text-right mt-3">` button row at the bottom of `.modal-body`
  as a stand-in for `.modal-footer`. That drops the BS3 footer styling
  (top border, padding, alignment) and produces visible drift from the
  pre-Phlex chrome. If you need a button row, use Pattern A.
- **Splitting the form across two slots.** Don't put fields in
  `with_body` and buttons in `with_footer` — the submit button ends up
  outside the `<form>` and clicking it submits nothing. Either span both
  via `:form_content` (Pattern A) or keep everything in `:body` (Pattern B).
- **Dropping `body_id` or `flash_id`.** Both kwargs are load-bearing
  (turbo-stream targets, in-modal flash). If your form doesn't need them
  for any reason, document why — don't silently omit.

### Form Objects

When a form doesn't map directly to an ActiveRecord model (e.g., action forms,
multi-step forms, or forms with custom param structures), create a **FormObject**.

**Location:** `app/classes/form_object/`

**Naming:** Use the concept name without "Form" suffix. The class is namespaced
under `FormObject::`.

```ruby
# Good - app/classes/form_object/inherit_classification.rb
class FormObject::InheritClassification < FormObject::Base
  attribute :parent, :string
  attribute :options, :integer
end

# Usage in view
render(Components::MyForm.new(
  FormObject::InheritClassification.new(parent: @parent_text_name),
  name: @name
))

# Params will be namespaced as: inherit_classification[parent]
```

#### Watch for a decorative `Model.new` passed to `super`

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

### GET Forms (Search Filters, Index Filters)

GET forms (search bars, index filters) still extend `ApplicationForm` with a
FormObject. Override `form_tag` to use GET method, and suppress CSRF tokens
since GET forms don't need them.

```ruby
# app/classes/form_object/my_filter.rb
class FormObject::MyFilter < FormObject::Base
  attribute :query, :string
end

# app/components/my_filter_form.rb
class Components::MyFilterForm < Components::ApplicationForm
  def initialize(model, **)
    super(model, id: "my_filter", **)
  end

  def view_template
    super do
      text_field(:query, label: false, placeholder: "Search...")
      submit(:SEARCH.l)
    end
  end

  def form_action
    my_index_path
  end

  private

  def form_tag(&block)
    form(action: form_action, method: :get,
         **form_attributes, &block)
  end

  def form_attributes
    {
      id: @attributes[:id],
      class: "my-form",
      data: { controller: "my-controller" }
    }
  end

  # GET forms don't need authenticity tokens or _method fields
  def authenticity_token_field; end
  def _method_field; end
end
```

See `LiveDataFilterForm` and `IdentifyFilterForm` for real examples.

### Custom Param Namespacing with model_name

`FormObject::Base#model_name` returns the demodulized class name, which
Superform uses for field `name` attributes. Override `self.model_name` when
params need a different namespace than the class name implies.

```ruby
# Default: FormObject::IdentifyFilter → identify_filter[term]
# Override to get: filter[term]
class FormObject::IdentifyFilter < FormObject::Base
  attribute :term, :string

  def self.model_name
    ActiveModel::Name.new(self, nil, "Filter")
  end
end
```

### FieldProxy: Fields Without a Superform Field Backing

`FieldProxy` is the underlying mechanism for any form field that can't be
reached via `field(:attr)` on the form's model / FormObject. It provides
the same interface as `Superform::Field` (`key`, `value`, `dom.id`,
`dom.name`, `dom.value`) so the field classes (`TextField`, `RadioField`,
`CheckboxField`, `SelectField`, …) render identical Bootstrap markup
whether or not the field is model-backed.

Most of the time you don't construct one by hand. Inside an
`ApplicationForm` subclass, the **field helpers accept either a Symbol or
a String** and dispatch through `FieldProxy` for you (PRs #4382, #4384):

```ruby
# Symbol — model-bound (Symbol path, today's default).
text_field(:title)

# Symbol + explicit `value:` — overrides the model's value.
# `name=` is the Superform-namespaced `model_name[foo]`; value comes
# from the caller, not from `model.foo`. Use this when the field's
# name belongs in the form's namespace but the value comes from
# somewhere else (controller-supplied state, etc.).
radio_field(:dates_any, ["false", range_label], ["true", any_label],
            value: @dates_any)

# String — raw HTML `name=`, no model namespacing, value from caller.
# Use this for fields under a different namespace from the form's
# model, or top-level params:
text_field("member[lat]", value: @member_lat, size: 8)
hidden_field("approved_rank", value: @approved_rank)
checkbox_field("reviewed[#{donation.id}]", checked: donation.reviewed)
```

The helpers in scope today: `text_field`, `textarea_field`,
`checkbox_field`, `radio_field`, `select_field`, `date_field`,
`number_field`, `password_field`, `file_field`, `hidden_field`,
`autocompleter_field`, `static_field`, `read_only_field`.

**When you DO construct `FieldProxy` directly**: when you're rendering
form inputs *outside* an `ApplicationForm` subclass (no surrounding
`<form>` tag, no field helpers available) — e.g., feedback / editor
components like `FormImageFields`, `FormNameFeedback`, `FormListFeedback`.

```ruby
# Outside-form usage (FormNameFeedback).
#
# `wrapper_options: { wrap_class: ... }` adds CSS classes to each
# choice's `<div class="radio">` (or `<div class="checkbox">`) wrapper.
# Use this to preserve pre-refactor row spacing — pre-Phlex forms
# and modals often put `.mb-2` on per-row `.radio` / `.checkbox` wrappers
# for vertical spacing, and Superform's default omits it.
proxy = Components::ApplicationForm::FieldProxy.new(
  "chosen_multiple_names", name.id
)
render(Components::ApplicationForm::RadioField.new(
  proxy, *options,
  wrapper_options: { wrap_class: "my-1 mr-4 d-inline-block" }
))

# Image fields have a factory method
proxy = ApplicationForm.image_field_proxy(:good_image, 123, :notes, "text")
render(Components::ApplicationForm::TextField.new(
  proxy,
  attributes: { rows: 2 },
  wrapper_options: { label: "Notes:" }
))
```

**Never use `fields_for`** — use the String / Symbol+value forms of the
field helpers, or Superform's `namespace` method.

### Self-review checklist for a new form component

After writing the component:

1. Write a component test in `test/components/` following the patterns in
   `.claude/rules/testing.md` (consolidate assertions per render, extract
   a DRY render helper, etc.). See `test/components/herbarium_form_test.rb`
   or `test/components/sequence_form_test.rb` for reference.
2. Self-review the component diff for any literal `input(`, `select(`,
   `textarea(`, or `option(` calls. If present, replace each with the
   helper or FieldProxy pattern before opening the PR.
3. **When refactoring an existing Phlex component, run an HTML-parity
   diff against the pre-refactor output before opening the PR.** Use
   the "Debugging Phlex Component Conversions" HTML-diff technique in
   `.claude/rules/testing.md`: keep a renamed `_Old` copy of the
   original component on the branch, write a one-off test that renders
   both with identical inputs and writes them to `/tmp/foo_old.html` +
   `/tmp/foo_new.html`, then `diff` the formatted output.

   For every difference, decide:
   - **Preserve** it via `wrapper_options: { wrap_class: ... }` on
     collection fields, `wrap_class:` on field helpers, explicit Phlex
     `class:` attrs, or whatever knob the new component exposes. Common
     drops to look for: `.mb-2` on `.radio` / `.checkbox` rows,
     `text-right`/`mt-3` on button rows, custom `data-*` attributes,
     ARIA labels, the modal's `.modal-header` vs. `.modal-body` /
     `.modal-footer` placement of submit buttons. See "Form Inside a
     Modal" above for the modal-form case specifically.
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

Before reaching for `table { thead { tr { ... } }; tbody { @rows.each { ... } } }` in a Phlex view, check whether `Components::Table` fits. It keeps Bootstrap table markup consistent, supports **multiple `<tbody>` elements** (call `t.body(**attrs) { ... }` more than once — each call is its own `<tbody>`), per-column `class:` + arbitrary HTML attrs (`width:`, `data:`, etc.) via `t.column(header, **attrs) { |row| cell }`, and reads more clearly than hand-rolled rows. Basically never skip it for a rows-of-data table — reach for it first, every time.

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

### Multiple `<tbody>` groups

Call `t.body(**attrs) { ... }` once per group; each call produces its own `<tbody>`, so accordion-style tables (a summary tbody + a collapsible `tbody.collapse` of sub-rows) work directly through the component — no need to drop to hand-rolled `table { ... }` for this case anymore.

### When `Components::Table` genuinely doesn't fit (rare)

Skip it, with a `# NOTE:` comment explaining why, only when the table needs:

- **Stimulus / Turbo data attrs on the `<table>` tag itself** — `<table data-controller="name-list" ...>` with table-level wiring. `Components::Table` doesn't forward arbitrary attrs to the `<table>` tag yet; a small extension would unlock this case if it comes up often enough to justify it.
- **Mixed-shape rows that don't share an iteration source** — e.g. one row per existing group + N blank "write-in" rows from an unrelated source. Row mode handles mixed shapes fine when they share a row sequence; two genuinely different sources of rows is awkward.
- **A table that isn't really "rows of data"** — e.g. a 3-column layout shell wrapping unrelated panels with a `colspan` footer. Components::Table's purpose is rows of data; bending it elsewhere creates worse abstractions than `table { ... }` directly.

If you find yourself wanting a feature Components::Table doesn't have, prefer adding a small primitive to the component (the `tbody_id:` kind of thing, or the multi-tbody support above) over a one-off escape hatch in your view.

`Components::Table` is at `app/components/table.rb`; tests in `test/components/table_test.rb`.

## Phlex Views (Full-Page Rendering)

Full-page Phlex views live in `app/views/controllers/` and are
rendered from controllers with `render(ViewClass.new(...), layout: true)`.
The `layout: true` is required so Rails wraps the output in the
application layout. Phlex components rendered as fragments (e.g.,
`ModalForm` in turbo_stream responses) do not use `layout: true`.

### Hot-Reloading

Phlex view files are autoloaded by Zeitwerk like any other Ruby file.
Changes are hot-reloaded in development — no server restart needed.

### Using `content_for` from Phlex Views

`content_for` works from Phlex views via `view_context`. Use the
**value form** (passing content directly) rather than the block form:

```ruby
# Good — value form
html = view_context.tag.li { view_context.some_helper(...) }
view_context.content_for(:edit_icons, html)

# Also works — calling a helper that internally uses content_for
view_context.add_show_title(:show_thing_title.t, @thing)
```

**Do NOT use `helpers.content_for` from controllers.** The `helpers`
proxy creates a separate context that does not share `@view_flow` with
the layout. Content stored there will not be visible to the layout.

### Adding Title Bar Icons from Phlex Show Pages

`add_edit_icons(@object, @user)` adds edit and destroy icons to the
title bar for models with both routes.

When a model has a destroy route but no edit route, render the destroy
icon directly from the Phlex view:

```ruby
def add_destroy_icon
  return unless @occurrence.can_edit?(@user)

  icon = view_context.tag.li do
    view_context.destroy_button(
      target: @occurrence, icon: :delete
    )
  end
  view_context.content_for(:edit_icons, icon)
end
```

Once an edit route exists, switch to
`view_context.add_edit_icons(@object, @user)` which handles both icons.

## Form Gotchas

### Nested `<form>` Elements Break Form Submission

HTML does not allow nested `<form>` elements. When a browser encounters
`<form>` inside `<form>`, it implicitly closes the outer form. Any
elements after the inner form (like the submit button) end up outside
the outer form.

**Symptom**: Clicking a submit button does nothing — no server request
at all. Controller tests pass fine (they bypass the browser DOM parser).

**Common source in MO**: `InteractiveImage` with `votes: true` renders
`button_to` helpers, which generate `<form>` elements. If rendered
inside a Superform component, the vote button forms nest inside it and
break it.

**Rule**: Always pass `votes: false` to `InteractiveImage` inside any
form context. Any component that generates `<form>` tags (`button_to`,
turbo form helpers) must not be nested inside another form.

**Detection**: Only system tests (Capybara/Cuprite) or manual browser
testing will reveal this. Controller tests do NOT catch it. Assert no
nested `<form>` elements in rendered HTML as a regression guard.

### Turbo Forms in MO

- `Turbo.config.forms.mode = "optin"` — only forms (or ancestors) with
  `data-turbo="true"` use Turbo submission.
- `ApplicationForm` defaults to `local: true` (no Turbo). Pass
  `local: false` to enable Turbo on a form.
- Rails UJS is commented out — `data-disable-with` has no effect
  without UJS or Turbo.

## Debugging Phlex component behavior

For the systematic "diff the HTML output first" debugging technique
(comparing old vs. new component output to isolate a regression), see
"Debugging Phlex Component Conversions" in `.claude/rules/testing.md` —
that's the canonical version of this workflow; don't duplicate it here.

**Note**: You may see errors like "Couldn't find template for digesting:
Components/Component" in test logs. This is harmless — Phlex components
are pure Ruby and don't have templates to digest. The test environment
suppresses these via a custom logger formatter in
`config/environments/test.rb`.

## Component Architecture

### Prefer Components Over Helpers

**Internalize logic into Phlex components** rather than calling view helpers when possible.

```ruby
# Good - Component method
def show_original_name?(img)
  return false unless original && img && img.original_name.present?

  helpers.permission?(img) ||
    (img.user && img.user.keep_filenames == "keep_and_show")
end

def render_original_filename(img_instance)
  return unless show_original_name?(img_instance)

  div(img_instance.original_name)
end

# Bad - Delegating to helper
def render_original_filename(img_instance)
  return unless img_instance

  raw(helpers.image_owner_original_name(img_instance, original))
end
```

### Sub-Components

**Extract complex sections into separate components** when they have clear boundaries and responsibilities.

Examples:
- `ImageVoteSection` - handles image voting UI
- `LightboxCaption` - builds lightbox captions

### Required Workflow for New Components

When creating new Phlex components:

1. **Decide reusable vs. single-use first** (see "Decide first: reusable
   or single-use?" above) and place the file accordingly.
2. **Create the component** with proper structure and type-safe props
3. **Write the implementation** following this style guide
4. **Access Literal props as `@instance_variables`** (not method calls)
5. **Never call `helpers` or `view_context`** - use registered helpers or include the appropriate Phlex::Rails::Helpers module instead
6. **Never use `form_with`** - always use Superform (extend `Components::ApplicationForm`)
7. **Run Rubocop** and fix all violations
8. **Run tests** if applicable
9. **Commit** only after Rubocop is clean

## Summary

The key principles are:
1. **Use Kit syntax for top-level `Components::*`** (`Icon(...)`, `Link(...)`); full namespace + `render()` for nested views, non-dispatched nested components, and everything under `Views` (which never gets Kit sugar)
2. **Prefer Phlex helpers** over Rails `tag`/`view_context` helpers in components
3. **Use `trusted_html`** for HTML-safe content (from `.t`, `.l`), never `raw()`
4. **Use Superform** for all forms, never `form_with`
5. **Render directly** instead of building arrays and joining
6. **Internalize logic** into components when possible
7. **Try `Components::Table` first** for any rows-of-data table — it now supports multiple `<tbody>` groups too
