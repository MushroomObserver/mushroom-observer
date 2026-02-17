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

See `.claude/ruby_style_guide.md` for general Ruby and ERB style conventions,
and `.claude/phlex_style_guide.md` for Phlex component conventions.

### Tag Helpers in ERB

**Use `tag.element_name` in ERB templates, never `content_tag`.**

```erb
<%# Good %>
<%= tag.div("Content", class: "my-class") %>
<%= tag.p(:some_translation.t, class: "help-note") %>
<%= tag.h4("Header") %>

<%# Bad - NEVER use content_tag %>
<%= content_tag(:div, "Content", class: "my-class") %>
<%= content_tag(:p, :some_translation.t, class: "help-note") %>
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
# Correct
bin/rails test test/components/application_form_test.rb -n test_text_field_renders_with_basic_options

# Wrong - will cause Exit code 1
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

## Summary

- **Always run Rubocop** on new/modified Ruby files
- **Always refactor Metrics violations** - do not leave them unfixed
- **Use extraction methods** to break up complex code
- **Verify clean Rubocop** before considering work complete

See `.claude/ruby_style_guide.md` for general Ruby/ERB style, testing, i18n,
and RuboCop guidelines. See `.claude/phlex_style_guide.md` for Phlex component
conventions, Superform usage, and component architecture.
