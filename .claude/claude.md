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
