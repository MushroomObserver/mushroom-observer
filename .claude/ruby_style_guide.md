# Mushroom Observer Ruby Style Guide

This document describes general Ruby, ERB, and project-level coding style
preferences. For Phlex component conventions, see `.claude/phlex_style_guide.md`.

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
vim config/locales/en.yml  # Wrong file
git add config/locales/en.yml  # Never commit .yml files
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
3. **Use Rails-preferred assertions** (`assert_no_match`, `assert_not_equal`, etc.) instead of MiniTest refute methods
4. **Run the full test suite** before creating any PR with production Rails code changes
5. **Edit `en.txt` for text strings**, run `rails lang:update`, never commit `.yml` files
6. **All new code must pass RuboCop** - refactor instead of disabling cops
