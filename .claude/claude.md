# Instructions for Claude Code

This document provides instructions for Claude Code when working on the Mushroom Observer codebase.

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

## Required Workflow for New Components

When creating new Phlex components:

1. **Create the component** with proper structure and type-safe props
2. **Write the implementation** following the style guide
3. **Run Rubocop** and fix all violations
4. **Run tests** if applicable
5. **Commit** only after Rubocop is clean

## Summary

✅ **Always run Rubocop** on new/modified Ruby files
✅ **Always refactor Metrics violations** - do not leave them unfixed
✅ **Use extraction methods** to break up complex code
✅ **Verify clean Rubocop** before considering work complete

See `.claude/style_guide.md` for additional coding style requirements.
