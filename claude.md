# Phlex Component Development Guide

## Phlex HTML Methods - No Positional Arguments

**IMPORTANT**: Phlex HTML methods (`div`, `span`, `p`, `a`, `li`, etc.) do NOT accept positional arguments for content. They only accept:
1. Named keyword arguments (attributes)
2. A block for content

### Examples:

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

## Including Rails Built-in Helpers

Rails helpers are available as Phlex modules under `Phlex::Rails::Helpers`. The module name matches the helper method name in PascalCase.

### Examples:
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

## Registering Custom Application Helpers

Custom helpers from `app/helpers/` should be registered in `app/components/base.rb` so they're available to all components.

### Registration Types:

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

### Important Rules:

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

## Literal Properties

All component properties must be accessed as instance variables (with `@`):

```ruby
class MyComponent < Components::Base
  prop :user, _Nilable(User)
  prop :name, String

  def view_template
    # Good ✓
    div { @user.name }
    p { @name }

    # Bad ✗
    div { user.name }   # NoMethodError
    p { name }          # NoMethodError
  end
end
```

## Common Patterns

### Using fields_for:
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

### Joining HTML strings:
Instead of using `safe_join`, use `array.join.html_safe`:
```ruby
# Good ✓
fields = [helper1(...), helper2(...), helper3(...)]
fields.join.html_safe

# Avoid (safe_join is not a standard Phlex helper)
safe_join(fields)
```

### Link helpers:
```ruby
class MyComponent < Components::Base
  include Phlex::Rails::Helpers::LinkTo

  def view_template
    link_to("View User", user_path(@user))
  end
end
```

### Converting Hash to URL:
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
