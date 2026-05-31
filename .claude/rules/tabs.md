# Tab POROs (`Tab::*`)

A tab is a navigation link that knows its title, URL, and selector
identity. Instead of free-floating `app/helpers/tabs/*_helper.rb`
methods that return `[title, url, html_options]` arrays, MO is moving
to PORO classes under `app/classes/tab/<domain>/<name>.rb`.

**Who consumes Tab POROs?** Mostly `add_context_nav(...)` — the
helper that populates the page's right-side context-nav dropdown
(`Components::ContextNav::TopBar`) + mobile sidebar
(`Components::ContextNav::Sidebar`). Most existing
`app/helpers/tabs/*_helper.rb` methods feed `add_context_nav` (e.g.
`add_context_nav(herbarium_show_tabs)`,
`add_context_nav(comment_form_new_tabs(target: @target))`). A
secondary consumer is `Components::NavTabs` — the Bootstrap
`nav-tabs` strip — used for the project banner and admin sub-tabs.

This page documents the conventions for writing and consuming Tab
POROs. The first foundational PR landed `Tab::Base`,
`Tab::Collection`, and the project domain (`Tab::Project::*`); see
those classes for the canonical examples.

## What's a Tab PORO?

```ruby
# app/classes/tab/project/summary.rb
class Tab::Project::Summary < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title    = :SUMMARY.t
  def path     = project_path(id: @project.id)
  def alt_title = "summary"

  # Banner's `current_tab` comes from controller_name → "projects".
  # Override nav_key when it diverges from alt_title.
  def nav_key  = "projects"
end
```

`Tab::Base` provides:

- `#to_internal_link` — returns the canonical `InternalLink` for
  consumers that want pre-resolved attrs.
- `#to_a` — returns the legacy `[title, url, html_options]` shape
  for `tabs.tab(*tab.to_a)` splat consumers (and for parity with
  the old helper-method API during migration).
- `#nav_key` — the identifier `Components::NavTabs` matches against
  `current:` to decide which tab is `.active`. Defaults to
  `alt_title` (a Tab's "short stable identifier" is the same
  concept for selector class and active-matching). Falls back to
  the demodulized class name when `alt_title` is nil. Override per
  subclass when the view's `current_tab` semantic differs (e.g.
  `Tab::Project::Summary` overrides to `"projects"` because the
  banner derives current_tab from `controller_name`).

The subclass implements `#title`, `#path`, plus optionally
`#alt_title` and `#html_options`.

## What's a Tab::Collection?

A composed group of Tab POROs — typically the tab strip in a page
header or the action-nav links for a controller action. Subclasses
implement private `#tabs` returning an Array of `Tab::Base`
instances:

```ruby
# app/classes/tab/project/banner.rb
class Tab::Project::Banner < Tab::Collection
  def initialize(project:, user:)
    super()
    @project = project
    @user = user
  end

  private

  def tabs
    [
      Tab::Project::Summary.new(project: @project),
      *body_tabs,
      admin_tab
    ].compact
  end

  # ... private composition methods ...
end
```

**Order matters.** The order of the returned array IS the visual
order in the rendered tab strip. Tests should pin the order
explicitly (`assert_equal([...class list...], coll.to_a.map(&:class))`)
under each conditional branch.

**Conditional inclusion lives in the Collection, not the view.**
The "show admin tab iff is_admin?" / "show update tab iff
has_targets? && is_admin?" logic moves out of the view and into
private methods on the Collection. This makes the conditionals
unit-testable without rendering a view.

## Consuming from `add_context_nav` (the common case)

Most Tab POROs / Collections feed the context-nav menu — the
right-side dropdown on a page header, plus its mobile-sidebar
equivalent. `add_context_nav` accepts a `Tab::Base`, a
`Tab::Collection`, or the legacy `Array<[text, url, opts]>` tuples:

```ruby
# Phlex view
add_context_nav(Tab::Herbarium::Show.new(herbarium: @herbarium))
# Collection (multi-tab)
add_context_nav(Tab::Comment::FormNew.new(target: @target))
# Legacy array (existing helpers/tabs/* callers — unchanged)
add_context_nav(herbarium_show_tabs)
```

For Tab::Base with non-link rendering (e.g. a destroy button), set
`html_options[:button]` to `:post` / `:destroy` / `:put` / `:patch`:

```ruby
class Tab::Comment::Destroy < Tab::Base
  def initialize(comment:); @comment = comment; super(); end
  def title = :DESTROY.t
  def path = comment_path(@comment.id)
  def html_options = { button: :destroy }
end
```

## Consuming from `Components::NavTabs` (the Bootstrap tab strip)

Used for in-page tab bars (project banner, project admin sub-tabs):

```ruby
render(Components::NavTabs.new(
  current: @current_tab,
  link_class: "mt-3",
  tabs: Tab::Project::Banner.new(project: @project, user: @user)
))
```

`tabs:` accepts any `Enumerable` of `Tab::Base` (so
`Tab::Collection` works directly; a raw `Array<Tab::Base>` works
too).

To mix a Collection with one-off tabs, use the builder + `add_all`:

```ruby
render(Components::NavTabs.new(current: @current_tab)) do |tabs|
  tabs.add_all(Tab::Project::Banner.new(project: @project, user: @user))
  tabs.tab(Tab::SomethingElse.new(...))
  tabs.tab("Bare", "/bare", key: "bare")
end
```

NavTabs auto-derives `key:` from each Tab's `nav_key`. Pass an
explicit `key:` to override.

## Namespace collisions to watch for

The top-level `Tab` namespace will collide with any class lexically
named `Tab` (e.g. an inner-class `class Tab < ...` inside a Phlex
view). The fix is to qualify as `::Tab::Project::Summary` (leading
`::`). The pattern hasn't shown up after the foundational PR (the
one such view, `Views::Controllers::Projects::Tabs`, was deleted),
but if a future Phlex view names itself `Tabs`, prefer renaming
the view (e.g. `TabBar`) to dodge the qualifier requirement.

## Testing Tab POROs

Single-tab tests are trivial — assert `title`, `path` (via route
helper, never a hardcoded URL — see
[testing.md](testing.md)), `alt_title`, `nav_key`:

```ruby
class Tab::Project::SummaryTest < UnitTestCase
  def routes
    Rails.application.routes.url_helpers
  end

  def setup
    @project = projects(:bolete_project)
  end

  def test_summary
    tab = Tab::Project::Summary.new(project: @project)

    assert_equal(:SUMMARY.t, tab.title)
    assert_equal(routes.project_path(id: @project.id), tab.path)
    assert_equal("summary", tab.alt_title)
    assert_equal("projects", tab.nav_key)
  end
end
```

**Use a `routes` proxy method, not
`include Rails.application.routes.url_helpers`.** Including the
module makes MiniTest pick up any route helper whose name happens
to start with `test_` (e.g. `test_index_url` for `/test`) as a
test method on the class, causing spurious failures.

Collection tests pin the order under each conditional branch:

```ruby
def test_banner_no_observations_no_species_lists_admin_user
  empty = projects(:empty_project)
  mary = users(:mary)

  tabs = Tab::Project::Banner.new(project: empty, user: mary).to_a

  assert_equal(
    [Tab::Project::Summary,
     Tab::Project::Names,
     Tab::Project::Locations,
     Tab::Project::Admin],
    tabs.map(&:class)
  )
end
```

`Collection#to_a` returns the Tab POROs themselves (via Enumerable's
default). `Collection#to_internal_links` returns InternalLinks if
you need pre-resolved attrs.

## Migration plan

The foundational PR converts the project domain only. Remaining
conversions are batched into three themed follow-up PRs — see
the `tab_poros_migration_plan` project-memory entry for the
ordered list.

When converting a domain:

1. For each helper method that returns
   `InternalLink.new(...).tab`, create one Tab PORO class.
2. For each helper method that returns an array of
   `InternalLink#tab` arrays (e.g. `user_show_tabs`), create one
   `Tab::Collection` subclass. Move conditional logic from the
   view callers into the Collection's private methods.
3. Update view callers to consume via NavTabs' `tabs:` kwarg or
   `add_all`.
4. Delete the helper methods from `app/helpers/tabs/<domain>_helper.rb`.
   If the file ends up empty, delete it AND remove its `include`
   from `config/initializers/phlex.rb`'s `to_prepare` block (the
   block currently auto-includes every `Tabs::*Helper` module into
   `Views::Base`).
5. Write tests covering single-tab POROs and Collections (with
   ordering assertions under every branch).
