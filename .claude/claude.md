# Instructions for Claude Code

This document provides instructions for Claude Code when working on the Mushroom Observer codebase.

## Coding Style Requirements

### Always Use Parentheses for Method Calls with Arguments

**Always use parentheses when calling methods that have arguments.**

This applies to:
- Ruby files (`.rb`)
- ERB templates (`.erb`)
- All method calls including `render`, helper methods, etc.

```ruby
# Good
render(component)
User.find(id)
link_to(text, path)
helper_method  # no args, no parens needed

# Bad
render component
User.find id
link_to text, path
```

See `.claude/style_guide.md` for comprehensive style examples.

### Tag Helpers in ERB and Components

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

### Line Length Limits

**Keep lines to 80 characters or less** in both Ruby and ERB files.

#### Ruby Files:
- Rubocop enforces 80 character line length
- Split long lines using:
  - Method chaining on new lines
  - Breaking long parameter lists
  - Extracting complex expressions to variables

```ruby
# Good
render(Components::InteractiveImage.new(
  user: @user,
  image: @image,
  votes: true
))

# Bad (too long)
render(Components::InteractiveImage.new(user: @user, image: @image, votes: true, size: :medium))
```

#### ERB Templates:
- **Also follow 80 character limit** even though Rubocop doesn't check ERB files
- Break long lines in ERB using the same techniques as Ruby
- ERB tags (`<%=`, `%>`) count toward the 80 character limit

```erb
<%# Good %>
<%= render(Components::InteractiveImage.new(
      user: @user,
      image: @image,
      votes: true
    )) %>

<%# Bad (too long) %>
<%= render(Components::InteractiveImage.new(user: @user, image: @image, votes: true)) %>
```

## Code Quality and Linting

### Always Run Rubocop on New Code

**After creating or modifying Ruby files, always run Rubocop to check for violations.**

#### Process:

1. **Run Rubocop** on the new/modified files:
   ```bash
   bundle exec rubocop path/to/file.rb --format simple
   ```

2. **Auto-correct** correctable violations:
   ```bash
   bundle exec rubocop path/to/file.rb --autocorrect-all
   ```

3. **Manually fix** remaining violations, especially:
   - Line length violations (split long lines)
   - Metrics violations (see below)
   - Style violations that cannot be auto-corrected

4. **Verify** all violations are resolved:
   ```bash
   bundle exec rubocop path/to/file.rb --format simple
   ```

   The output should show: "X files inspected, no offenses detected"

## Running Tests

### Correct Syntax for Running Individual Tests

**IMPORTANT**: When running a single test, use the `-n` flag with the test method name.

```bash
# ✅ Correct
bin/rails test test/components/application_form_test.rb -n test_text_field_renders_with_basic_options

# ❌ Wrong - will cause Exit code 1
bin/rails test test/components/application_form_test.rb::ApplicationFormTest#test_text_field_renders_with_basic_options
```

**Syntax for running tests:**
- Run all tests in a file: `bin/rails test path/to/test_file.rb`
- Run a single test: `bin/rails test path/to/test_file.rb -n test_method_name`
- Run all tests in a directory: `bin/rails test test/components/`

### Refactoring Metrics Violations

**Always refactor code that has Metrics violations.** Do not leave them unfixed.

Common Metrics violations:
- `Metrics/AbcSize` - Assignment Branch Condition size (complexity)
- `Metrics/MethodLength` - Method is too long
- `Metrics/ClassLength` - Class is too long
- `Metrics/CyclomaticComplexity` - Too many branches
- `Metrics/PerceivedComplexity` - Code is too complex

#### Refactoring Strategies:

1. **Extract methods** - Break large methods into smaller, focused methods
   ```ruby
   # Before - AbcSize violation
   def complex_method
     # 30 lines of logic with multiple branches and calculations
   end

   # After - Extracted into smaller methods
   def complex_method
     prepare_data
     process_data
     render_result
   end

   def prepare_data
     # focused preparation logic
   end

   def process_data
     # focused processing logic
   end

   def render_result
     # focused rendering logic
   end
   ```

2. **Extract conditional logic** into predicate methods
   ```ruby
   # Before
   if user && obs_user != user && !obs_user&.no_emails && obs_user&.email_general_question
     # ...
   end

   # After
   if show_contact_link?(obs_user)
     # ...
   end

   def show_contact_link?(obs_user)
     user && obs_user != user && !obs_user&.no_emails &&
       obs_user&.email_general_question
   end
   ```

3. **Extract data structures** - Move complex hashes/arrays to separate methods
   ```ruby
   # Before
   h4(
     id: "...",
     class: "...",
     data: { controller: "...", value: user&.id }
   ) do
     # content
   end

   # After
   h4(title_attributes) do
     # content
   end

   def title_attributes
     {
       id: "...",
       class: "...",
       data: { controller: "...", value: user&.id }
     }
   end
   ```

4. **Use guard clauses** to reduce nesting
   ```ruby
   # Before
   def method
     if condition
       # many lines
     end
   end

   # After
   def method
     return unless condition

     # many lines (now less indented)
   end
   ```

### Examples from This Codebase

See these files for good examples of refactored code:
- `app/components/image_vote_section.rb` - Extracted `render_current_vote` and `render_vote_button`
- `app/components/lightbox_caption.rb` - Extracted multiple helper methods to reduce complexity

## Phlex and Literal Components

### Accessing Literal Properties

**IMPORTANT**: Literal::Properties must be accessed as instance variables, not as method calls.

```ruby
class Components::Example < Components::Base
  prop :user, _Nilable(User)
  prop :cached, _Boolean, default: false

  def view_template
    # ✅ Correct - access as instance variable
    return unless @user
    if @cached
      # ...
    end

    # ❌ Wrong - will cause "undefined local variable or method" error
    return unless user
    if cached
      # ...
    end
  end
end
```

### Phlex HTML Element Syntax

**Empty Elements**: Don't pass empty strings to Phlex HTML elements.

```ruby
# ✅ Correct
div(class: "clearfix")
span(class: "badge")

# ❌ Wrong
div("", class: "clearfix")
span("", class: "badge")
```

### Phlex Slots in ERB Templates

**CRITICAL**: Phlex slot blocks behave differently in ERB templates vs pure
Ruby/Phlex code.

#### In Pure Ruby/Phlex Code (Tests, Components)

Inline blocks work fine because the block's return value is captured:

```ruby
# ✅ Works in test files and pure Phlex components
render(Components::Panel.new) do |panel|
  panel.with_heading { "Test Heading" }
  panel.with_body { "Content" }
end
```

#### In ERB Templates

Blocks must explicitly output content using `<%= %>` tags, not just return
values:

```erb
<%# ❌ Wrong - block returns value but doesn't output to ERB buffer %>
<%= panel.with_heading { "Test" } %>
<%= panel.with_heading { :NOTES.l } %>

<%# ✅ Correct - block explicitly outputs content to ERB buffer %>
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
# ❌ Wrong - Phlex HTML methods don't work in slot blocks
render(Components::Panel.new) do |panel|
  panel.with_thumbnail do
    img(src: "/path/to/image.jpg", alt: "Thumbnail")  # NoMethodError!
  end
end

# ✅ Correct - Use view_context.tag helpers
render(Components::Panel.new) do |panel|
  panel.with_thumbnail do
    view_context.tag.img(
      src: "/path/to/image.jpg",
      alt: "Thumbnail",
      class: "img-thumbnail"
    )
  end
end

# ✅ Also correct - Plain HTML strings work
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

### Rendering Phlex Fragments

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

### Fragment Caching in Phlex

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

### Template Digesting Errors

**Note**: You may see errors like "Couldn't find template for digesting: Components/Component" in test logs. This is harmless - Phlex components are pure Ruby and don't have ERB templates to digest.

The test environment has been configured to suppress these errors via a custom logger formatter in `config/environments/test.rb`.

## Required Workflow for New Components

When creating new Phlex components:

1. **Create the component** with proper structure and type-safe props
2. **Write the implementation** following the style guide
3. **Access Literal props as `@instance_variables`** (not method calls)
4. **Never call `helpers` or `view_context`** - use registered helpers or include the appropriate Phlex::Rails::Helpers module instead
5. **Never use `form_with`** - always use Superform (extend `Components::ApplicationForm`)
6. **Run Rubocop** and fix all violations
7. **Run tests** if applicable
8. **Commit** only after Rubocop is clean

## Debugging ERB to Phlex Conversions

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

## Summary

✅ **Always run Rubocop** on new/modified Ruby files
✅ **Always refactor Metrics violations** - do not leave them unfixed
✅ **Use extraction methods** to break up complex code
✅ **Verify clean Rubocop** before considering work complete

See `.claude/style_guide.md` for additional coding style requirements.

## Phlex Component Development

### Including Rails Built-in Helpers

Rails helpers are available as Phlex modules under `Phlex::Rails::Helpers`. The module name matches the helper method name in PascalCase.

#### Examples:
```ruby
class Components::MyComponent < Components::Base
  include Phlex::Rails::Helpers::LinkTo      # for link_to
  include Phlex::Rails::Helpers::ButtonTo    # for button_to
  include Phlex::Rails::Helpers::FieldsFor   # for fields_for
  include Phlex::Rails::Helpers::SafeJoin    # for safe_join
  include Phlex::Rails::Helpers::ImageTag    # for image_tag
  include Phlex::Rails::Helpers::ClassNames  # for class_names
end
```

After including the module, call the helper directly without any prefix:
```ruby
link_to("Click me", some_path)
button_to(some_path, method: :delete)
fields_for(:user) do |f|
  # field rendering
end
```

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

1. **DO NOT register Rails built-in helpers** like `fields_for`, `safe_join`, `link_to`, etc. Use `include` instead.

2. **DO NOT register helpers that accept blocks** - these need special handling and may not work correctly with `register_output_helper`.

3. After registration, call helpers directly without the `helpers.` prefix:
```ruby
# Good ✓
propose_naming_link(@obs.id, context: "lightbox")
location_link(@obs.where, @obs.location)

# Bad ✗
helpers.propose_naming_link(...)
helpers.location_link(...)
```

4. Use `raw()` sparingly - only for HTML strings that are already marked safe. Registered output helpers don't need `raw()` wrapping.

### Using `raw()` for HTML Strings

**IMPORTANT**: Phlex's `raw()` method only accepts content that has been explicitly marked as safe with `.html_safe`.

#### Examples:
```ruby
# Bad ✗ - will raise "You passed an unsafe object to raw"
raw("<strong>#{label}: </strong>")
raw(parts.join(", "))
raw(@links)

# Good ✓ - mark content as safe first
raw("<strong>#{label}: </strong>".html_safe)
raw(parts.join(", ").html_safe)
raw(@links.html_safe)
```

#### When to use `raw()`:
- For HTML strings you've built manually that need to be rendered
- For string properties that contain HTML markup
- Only when you trust the content (never for user input)

#### When NOT to use `raw()`:
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
# ✅ Correct - output directly
@obs.user_format_name(@user).t.small_author
location_link(@where, @location)
some_helper_that_returns_html

# ❌ Wrong - will double-escape HTML
plain(@obs.user_format_name(@user).t.small_author)  # Produces &lt;b&gt;&lt;i&gt;Name&lt;/i&gt;&lt;/b&gt;
```

#### When to use `plain()`:
- For literal strings without HTML
- For interpolated text that should be escaped
- For user-generated content that must be sanitized

#### When to output directly (no `plain()`):
- For registered output helpers (they return `html_safe` strings)
- For Rails helper methods that return HTML (`link_to`, `button_to`, etc.)
- For formatted text methods that return HTML (`.t`, `.tpl`, etc.)
- For any string already marked `.html_safe`

### Prefer Phlex Methods Over ActionView Helpers

When possible, use native Phlex HTML methods instead of Rails ActionView tag helpers. Phlex methods are more idiomatic and don't require extra includes.

#### Examples:

##### Labels:
```ruby
# Avoid ✗ - requires include Phlex::Rails::Helpers::LabelTag
include Phlex::Rails::Helpers::LabelTag
label_tag(:field_name, class: "label-class", data: { ... })

# Prefer ✓ - native Phlex method
label(for: "field_name", class: "label-class", data: { ... }) { "Label text" }
```

##### Buttons:
```ruby
# Avoid ✗ - requires include Phlex::Rails::Helpers::ButtonTag
include Phlex::Rails::Helpers::ButtonTag
button_tag("Click me", type: "button", class: "btn")

# Prefer ✓ - native Phlex method
button(type: "button", class: "btn") { "Click me" }
```

##### Divs, Spans, etc:
```ruby
# Always use native Phlex methods
div(class: "container") { "Content" }
span(class: "badge") { "New" }
p(class: "text") { "Paragraph" }
```

#### When to use Rails helpers:
- For form helpers like `fields_for`, `form_with`, etc.
- For specialized helpers like `link_to`, `image_tag` that have complex behavior
- For helpers that don't have Phlex equivalents

### Common Patterns

#### Using fields_for:
```ruby
class MyFormComponent < Components::Base
  include Phlex::Rails::Helpers::FieldsFor

  def view_template
    fields_for(:user) do |f|
      render_form_fields(f)
    end
  end

  private

  def render_form_fields(form)
    fields = [
      text_field_with_label(form: form, field: :name),  # custom registered helper
      email_field_with_label(form: form, field: :email) # custom registered helper
    ]

    # Use array.join.html_safe instead of safe_join
    fields.join.html_safe
  end
end
```

#### Joining HTML strings:
Instead of using `safe_join`, use `array.join.html_safe`:
```ruby
# Good ✓
fields = [helper1(...), helper2(...), helper3(...)]
fields.join.html_safe

# Avoid (safe_join is not a standard Phlex helper)
safe_join(fields)
```

#### Link helpers:
```ruby
class MyComponent < Components::Base
  include Phlex::Rails::Helpers::LinkTo

  def view_template
    link_to("View User", user_path(@user))
  end
end
```

#### Converting Hash to URL:
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

## Component Organization

### Favor Top-Level Components Over Namespacing

**Important**: Prefer flat, top-level component organization over nested namespaces.

**Reason**: The phlex-rails Kit syntax (which enables automatic rendering of components by name) does not work with namespaced components. Kit syntax is much more ergonomic than calling `render()`, so it's worth keeping components at the top level to enable this feature.

#### Examples:

```ruby
# ✅ Good - top-level components (enables Kit syntax)
Components::Panel
Components::PanelHeading
Components::PanelBody
Components::PanelFooter

# ❌ Avoid - namespaced components (breaks Kit syntax)
Components::Panel
Components::Panel::Heading
Components::Panel::Body
Components::Panel::Footer
```

**Context**: We initially tried namespacing the Panel subcomponents as `Panel::Heading`, `Panel::Body`, etc., but discovered that this breaks the Kit syntax feature in phlex-rails (see [issue #316](https://github.com/yippee-fun/phlex-rails/issues/316)). Since Kit syntax provides significant developer experience benefits, we've chosen to use top-level components instead.

**Naming Convention**: For related components, use a consistent prefix (e.g., `PanelHeading`, `PanelBody`, `PanelFooter`) to indicate their relationship while keeping them at the top level.
