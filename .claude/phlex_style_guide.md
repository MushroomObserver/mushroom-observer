# Mushroom Observer Phlex Component Style Guide

This document describes Phlex component conventions, Superform usage, and
component architecture. For general Ruby and ERB style, see
`.claude/ruby_style_guide.md`.

## Form Components (Superform)

Form components extend `Components::ApplicationForm`. Read this file, as well as
the `superform` gem, before beginning a conversion.

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
select_field(:rank, rank_options, label: "Rank:")
static_field(:display_name, label: "Name:", value: @model.name, inline: true)
read_only_field(:locked_field, label: "Value:", value: @value)

# Bad - Verbose render(field(...)) pattern
render(field(:name).text(wrapper_options: { label: "Name:" }, size: 40))
render(field(:notes).textarea(wrapper_options: { label: "Notes:" }, rows: 6))
```

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

**Use Phlex's native HTML helpers** instead of Rails `tag` helpers wrapped in `unsafe_raw`.

```ruby
# Good - Native Phlex
div(class: "container", id: "main") do
  h1("Title")
  p(class: "description") do
    plain("Some text")
  end
end

# Bad - Rails tag helpers
raw(
  helpers.tag.div(class: "container", id: "main") do
    helpers.tag.h1("Title")
    helpers.tag.p("Some text", class: "description")
  end
)
```

### Tag Helpers in ERB vs Components

**Use `tag.element_name` in ERB templates, never `content_tag`.**

In ERB files:
```erb
<%# Good %>
<%= tag.div("Content", class: "my-class") %>
<%= tag.p(:some_translation.t, class: "help-note") %>
<%= tag.h4("Header") %>

<%# Bad - NEVER use content_tag %>
<%= content_tag(:div, "Content", class: "my-class") %>
<%= content_tag(:p, :some_translation.t, class: "help-note") %>
```

**Use native Phlex HTML methods in components, never `view_context.tag`.**

In Phlex components:
```ruby
# Good - use native Phlex methods
def view_template
  div("Content", class: "my-class")
  p(:some_translation.t, class: "help-note")
  h4("Header")
end

# Bad - NEVER use view_context.tag
def view_template
  view_context.tag.div("Content", class: "my-class")
  view_context.tag.p(:some_translation.t, class: "help-note")
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

### FieldProxy: Form Fields Outside a Form Context

When you need to render Superform field components (e.g., `TextField`,
`RadioField`) **outside** of a `Superform::Rails::Form`, use `FieldProxy`.
This is common in feedback components and image field editors that render
form inputs without owning the `<form>` tag.

`FieldProxy` provides the same interface as `Superform::Field` (`key`, `value`,
`dom.id`, `dom.name`, `dom.value`) so field components work identically.

```ruby
# Create a proxy for a namespaced field
proxy = Components::ApplicationForm::FieldProxy.new(
  "chosen_multiple_names", name.id
)
render(Components::ApplicationForm::RadioField.new(
  proxy, *options,
  wrapper_options: { wrap_class: "my-1 mr-4 d-inline-block" }
))

# For image fields, use the factory method
proxy = ApplicationForm.image_field_proxy(:good_image, 123, :notes, "text")
render(Components::ApplicationForm::TextField.new(
  proxy,
  attributes: { rows: 2 },
  wrapper_options: { label: "Notes:" }
))
```

**When to use FieldProxy:**
- Components that render form inputs but don't own the `<form>` tag
  (e.g., `FormImageFields`, `FormListFeedback`, `FormNameFeedback`)
- Standalone radio groups or other inputs outside a Superform form

**Never use `fields_for`** — use `FieldProxy` or Superform's `namespace`
method instead.

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

## Phlex Slots in ERB Templates

**CRITICAL**: Phlex slot blocks behave differently in ERB templates vs pure
Ruby/Phlex code.

### In Pure Ruby/Phlex Code (Tests, Components)

Inline blocks work fine because the block's return value is captured:

```ruby
# Works in test files and pure Phlex components
render(Components::Panel.new) do |panel|
  panel.with_heading { "Test Heading" }
  panel.with_body { "Content" }
end
```

### In ERB Templates

Blocks must explicitly output content using `<%= %>` tags, not just return
values:

```erb
<%# Bad - block returns value but doesn't output to ERB buffer %>
<%= panel.with_heading { "Test" } %>
<%= panel.with_heading { :NOTES.l } %>

<%# Good - block explicitly outputs content to ERB buffer %>
<%= panel.with_heading do %>
  Test
<% end %>

<%= panel.with_heading do %>
  <%= :NOTES.l %>
<% end %>
```

**Why the difference?**
- In pure Ruby/Phlex, `yield` captures the block's return value
- In ERB, the block needs to output to the ERB buffer via `<%= %>`

**When fixing existing code:**
- Test files (`.rb`) with `panel.with_heading { "string" }` are fine
- ERB files (`.erb`) with `panel.with_heading { "string" }` need fixing

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
4. It works in any context - tests, ERB, slot blocks, etc.

**Note**: In actual component code (inside `view_template`), use native Phlex HTML methods like `img()`, `div()`, etc. This pattern is only needed for test slot blocks.

## Rendering Phlex Fragments

**To render specific fragments from a Phlex component**, use the `.call(fragments: [...])` method:

```erb
<%# Render only the "copyright" fragment from ImageInfo component %>
<%= Components::ImageInfo.new(
      user: @user,
      image: @image
    ).call(fragments: ["copyright"]) %>
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

Resources:
- Phlex documentation: https://www.phlex.fun/
- Phlex caching: https://www.phlex.fun/components/caching
- Literal properties: https://literal.fun/docs/properties.html

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

### Favor Top-Level Components Over Namespacing

**Important**: Prefer flat, top-level component organization over nested namespaces.

**Reason**: The phlex-rails Kit syntax (which enables automatic rendering of components by name) does not work with namespaced components. Kit syntax is much more ergonomic than calling `render()`, so it's worth keeping components at the top level to enable this feature.

#### Examples:

```ruby
# Good - top-level components (enables Kit syntax)
Components::Panel
Components::PanelHeading
Components::PanelBody
Components::PanelFooter

# Bad - namespaced components (breaks Kit syntax)
Components::Panel
Components::Panel::Heading
Components::Panel::Body
Components::Panel::Footer
```

**Context**: We initially tried namespacing the Panel subcomponents as `Panel::Heading`, `Panel::Body`, etc., but discovered that this breaks the Kit syntax feature in phlex-rails (see [issue #316](https://github.com/yippee-fun/phlex-rails/issues/316)). Since Kit syntax provides significant developer experience benefits, we've chosen to use top-level components instead.

**Naming Convention**: For related components, use a consistent prefix (e.g., `PanelHeading`, `PanelBody`, `PanelFooter`) to indicate their relationship while keeping them at the top level.

### Required Workflow for New Components

When creating new Phlex components:

1. **Create the component** with proper structure and type-safe props
2. **Write the implementation** following the style guide
3. **Access Literal props as `@instance_variables`** (not method calls)
4. **Never call `helpers` or `view_context`** - use registered helpers or include the appropriate Phlex::Rails::Helpers module instead
5. **Never use `form_with`** - always use Superform (extend `Components::ApplicationForm`)
6. **Run Rubocop** and fix all violations
7. **Run tests** if applicable
8. **Commit** only after Rubocop is clean

### Debugging ERB to Phlex Conversions

**CRITICAL**: When converting ERB partials to Phlex components, the ONLY thing
changing is the HTML output. Therefore, ALL NEW bugs come from HTML differences.
Comparing HTML will eliminate 90% of debugging work.

When a Phlex component doesn't work correctly but the ERB version did:

1. **Compare HTML output in detail** - This is your FIRST debugging step
2. Check for differences in:
   - Element IDs (exact match required for JS `getElementById`)
   - Element names (form field names must match exactly)
   - Data attributes (Stimulus targets, actions, controllers)
   - Class names (may affect JS selectors or CSS)
   - Nesting structure (parent elements may have required attributes)
   - Attribute values (case-sensitive, exact formatting)

3. **Use browser dev tools** to compare rendered HTML side-by-side
4. **Check Stimulus targets** - data-controller, data-*-target, data-action
5. **Check form field names** - Rails expects specific formats like `model[field]`

The JS/Stimulus code hasn't changed - if it worked before, the HTML difference
is the cause of any new bugs.

### Template Digesting Errors

**Note**: You may see errors like "Couldn't find template for digesting: Components/Component" in test logs. This is harmless - Phlex components are pure Ruby and don't have ERB templates to digest.

The test environment has been configured to suppress these errors via a custom logger formatter in `config/environments/test.rb`.

## Summary

The key principles are:
1. **Prefer Phlex helpers** over Rails `tag` helpers in components
2. **Use `trusted_html`** for HTML-safe content (from `.t`, `.l`), never `raw()`
3. **Use Superform** for all forms, never `form_with`
4. **Render directly** instead of building arrays and joining
5. **Internalize logic** into components when possible
6. **Favor flat component organization** over nested namespaces
