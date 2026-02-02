# Mushroom Observer Ruby Style Guide

This document describes coding style preferences for the Mushroom Observer codebase.

## General Ruby Style

### Method Calls with Parentheses

**Always use parentheses for method calls with arguments**, even in ERB templates.

**This applies to:**
- Ruby code
- ERB templates (`.erb` files)
- Code examples in comments
- Documentation in all files

#### Ruby Code

```ruby
# Good
render(component)
no_args_helper_method
User.find(id)
@objects.empty?

# Bad
render component
User.find id
```

#### ERB Templates

```erb
<%# Good %>
<%= render(Components::MatrixBox.new(user: @user, object: @obs)) %>
<%= link_to(text, path) %>
<%= tag.div(class: "container") do %>
  <%= content %>
<% end %>

<%# Bad %>
<%= render Components::MatrixBox.new(user: @user, object: @obs) %>
<%= link_to text, path %>
<%= tag.div class: "container" do %>
  <%= content %>
<% end %>
```

#### Comments and Documentation

Even in comments, use parentheses for method calls to maintain consistency:

```ruby
# Good
#  5) Add "show log" link at bottom of model's show page:
#       <%= render(Components::ObjectFooter.new(user: @user, obj: @object)) %>

# Bad
#  5) Add "show log" link at bottom of model's show page:
#       <%= render Components::ObjectFooter.new(user: @user, obj: @object) %>
```

### Component Namespacing

**Always use the full namespace** when referencing Phlex components in ERB or Ruby.

```ruby
# Good
render(Components::MatrixBox.new(...))
render(Components::InteractiveImage.new(...))

# Bad
render(MatrixBox.new(...))
render(InteractiveImage.new(...))
```

**However, when referencing Phlex components from other components, use "kit" syntax**.

```ruby
module Components
  class Panel

    def render_interactive_image
      # Good
      InteractiveImage(...)

      # Too verbose
      render(Components::InteractiveImage.new(...))
    end
  end
end
```

## Phlex Component Style

### Form Components (Superform)

Form components extend `Components::ApplicationForm` which provides helper methods
for rendering fields. **Always use these helpers** instead of the verbose
`render(field(...).xxx(...))` pattern.

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

#### Pattern B Forms: Internal FormObject Creation

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

### Rendering Content

**Use Phlex rendering methods** for outputting content:
- `plain(text)` - for plain text
- `whitespace` - for spacing between elements
- `trusted_html(html)` - for HTML-safe strings (ActiveSupport::SafeBuffer) from Rails helpers
- `raw(html)` - only when necessary for HTML strings that are not already marked safe

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

# Bad - using raw() for HTML-safe content
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
- Only use `raw()` for HTML strings that are not already marked as safe

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

## ERB Template Style

### Parentheses in Templates

**Always use parentheses** for method calls in ERB templates, including `render`, `link_to`, `tag` methods, etc.

```erb
<%# Good %>
<%= render(Components::MatrixTable.new(objects: @objects)) %>
<%= link_to(:BACK.t, observations_path) %>
<%= tag.div(class: "alert") do %>
  <%= flash_message %>
<% end %>

<%# Bad %>
<%= render Components::MatrixTable.new(objects: @objects) %>
<%= link_to :BACK.t, observations_path %>
<%= tag.div class: "alert" do %>
  <%= flash_message %>
<% end %>
```

### Component Blocks

**Use parentheses consistently** with component blocks.

```erb
<%# Good %>
<%= render(Components::MatrixBox.new(id: image.id) do %>
  <%= tag.div(class: "content") do %>
    <%= image.name %>
  <% end %>
<% end) %>

<%# Bad %>
<%= render Components::MatrixBox.new(id: image.id) do %>
  <%= tag.div class: "content" do %>
    <%= image.name %>
  <% end %>
<% end %>
```

## Testing

### Test Assertions

**Use Rails-preferred assertion methods** instead of MiniTest refute methods.

```ruby
# Good - Rails-preferred assertions
assert_no_match(/pattern/, string)
assert_not_equal(expected, actual)
assert_not_includes(collection, item)
assert_not_nil(value)

# Bad - MiniTest refute methods
refute_match(/pattern/, string)
refute_equal(expected, actual)
refute_includes(collection, item)
refute_nil(value)
```

**Why prefer assert_* over refute_*?**
- Rails coding standards prefer positive assertions with `assert_not` or `assert_no_*`
- RuboCop's `Rails/RefuteMethods` cop enforces this convention
- Consistent with Rails community practices

### Running Tests Before Creating PRs

**ALWAYS run the full test suite before creating a PR that includes changes to production Rails code.**

```bash
# Run the full test suite (coverage reports generated automatically)
bin/rails test
```

**Why run the full test suite?**
- Component unit tests may pass but integration tests can fail
- Changes to shared components (like FormLocationFeedback) are used by multiple controllers and views
- Type mismatches and parameter issues often only surface in integration tests
- Prevents breaking production code and having to fix issues after PR creation

**When to run the full suite:**
- Before creating any PR with changes to:
  - Components (`app/components/`)
  - Models (`app/models/`)
  - Controllers (`app/controllers/`)
  - Helpers (`app/helpers/`)
  - Views (`app/views/`)
- After making changes that affect multiple files
- When in doubt, always run it - better safe than sorry

**What to check:**
- All tests pass (0 failures, 0 errors)
- Pay attention to the error count, not just test count
- If tests fail, fix the issues before creating the PR
- Don't create PRs with known failing tests

## Internationalization

### Text Strings and Localization

**Always add text strings to `config/locales/en.txt`, never to `.yml` files.**

The `.yml` locale files are generated from `.txt` files and should never be edited or committed directly.

**Workflow for adding/updating text strings:**

1. Edit `config/locales/en.txt` to add or modify text strings
2. Run `rails lang:update` to regenerate all `.yml` files
3. Verify the change appears correctly in `config/locales/en.yml`
4. **Never commit the `.yml` files** - they are ignored by git

```bash
# Good workflow
vim config/locales/en.txt
rails lang:update
git add config/locales/en.txt
git commit -m "Update help text"

# Bad - never do this
vim config/locales/en.yml  # ❌ Wrong file
git add config/locales/en.yml  # ❌ Never commit .yml files
```

**Why this matters:**
- `.txt` files are the single source of truth for translations
- The `lang:update` rake task propagates changes to all language `.yml` files
- Editing `.yml` files directly causes changes to be lost on next update
- All `.yml` files are in `.gitignore` and should remain uncommitted

## Code Quality and Linting

### RuboCop Compliance

**All new code must pass RuboCop without violations.** Disabling RuboCop cops should be avoided.

```ruby
# Bad - Disabling cops
# rubocop:disable Metrics/MethodLength
def long_method
  # ... many lines of code
end
# rubocop:enable Metrics/MethodLength

# Good - Refactor to fix violations
def long_method
  prepare_data
  process_records
  generate_output
end

def prepare_data
  # ... extracted logic
end

def process_records
  # ... extracted logic
end

def generate_output
  # ... extracted logic
end
```

**When RuboCop flags a violation:**
1. **Refactor the code** to fix the violation properly
2. Break large methods into smaller, focused helper methods
3. Simplify complex conditionals
4. Extract magic numbers into named constants
5. Only disable cops as an absolute last resort with clear justification

**Exceptions:**
- Legacy code that hasn't been refactored yet may have disabled cops
- When updating legacy code, try to improve it toward RuboCop compliance
- If you must disable a cop, document why in a comment

## Summary

The key principles are:
1. **Always use parentheses** for method calls (Ruby and ERB)
2. **Use full namespaces** for component references (`Components::ClassName`)
3. **Prefer Phlex helpers** over Rails `tag` helpers in components
4. **Render directly** instead of building arrays and joining
5. **Internalize logic** into components when possible
6. **Use Rails-preferred assertions** (`assert_no_match`, `assert_not_equal`, etc.) instead of MiniTest refute methods
7. **Run the full test suite** before creating any PR with production Rails code changes
8. **Use `trusted_html`** for HTML-safe content (from `.t`, `.l`), not `raw()`
9. **Edit `en.txt` for text strings**, run `rails lang:update`, never commit `.yml` files
10. **All new code must pass RuboCop** - refactor instead of disabling cops
