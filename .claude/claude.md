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
4. **Run Rubocop** and fix all violations
5. **Run tests** if applicable
6. **Commit** only after Rubocop is clean

## Summary

✅ **Always run Rubocop** on new/modified Ruby files
✅ **Always refactor Metrics violations** - do not leave them unfixed
✅ **Use extraction methods** to break up complex code
✅ **Verify clean Rubocop** before considering work complete

See `.claude/style_guide.md` for additional coding style requirements.

## Phlex Component Development

### Phlex HTML Methods - No Positional Arguments

**IMPORTANT**: Phlex HTML methods (`div`, `span`, `p`, `a`, `li`, etc.) do NOT accept positional arguments for content. They only accept:
1. Named keyword arguments (attributes)
2. A block for content

#### Examples:

```ruby
# Bad ✗ - positional argument not allowed
div("", class: "progress-bar")
span("Click here", class: "label")

# Good ✓ - use a block for content
div(class: "progress-bar")  # empty div
span(class: "label") { "Click here" }
p(class: "text") { "Hello world" }

# Good ✓ - no content, just attributes
div(class: "progress-bar", id: "meter", style: "width: 50%")
```

If you see errors like `wrong number of arguments (given X, expected Y)` on a Phlex HTML method call, check if you're passing a positional argument instead of using a block.

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
