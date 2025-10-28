# Mushroom Observer Ruby Style Guide

This document describes coding style preferences for the Mushroom Observer codebase.

## General Ruby Style

### Method Calls with Parentheses

**Always use parentheses for method calls**, even when there are no arguments and even in ERB templates.

#### Ruby Code

```ruby
# Good
render(component)
helper_method()
User.find(id)
@objects.empty?()

# Bad
render component
helper_method
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

### Component Namespacing

**Always use the full namespace** when referencing Phlex components.

```ruby
# Good
render(Components::MatrixBox.new(...))
render(Components::InteractiveImage.new(...))

# Bad
render(MatrixBox.new(...))
render(InteractiveImage.new(...))
```

## Phlex Component Style

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
- `raw(html)` - only when necessary for Rails helpers that return HTML strings

```ruby
# Good
def view_template
  div do
    plain("Hello ")
    b("World")
    whitespace
    plain("!")
  end
end

# Bad - using safe_join or building arrays
def view_template
  div do
    raw(safe_join(["Hello ", tag.b("World"), "!"]))
  end
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

## Summary

The key principles are:
1. **Always use parentheses** for method calls (Ruby and ERB)
2. **Use full namespaces** for component references (`Components::ClassName`)
3. **Prefer Phlex helpers** over Rails `tag` helpers in components
4. **Render directly** instead of building arrays and joining
5. **Internalize logic** into components when possible
