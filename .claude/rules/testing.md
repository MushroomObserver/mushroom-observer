---
paths: test/**/*.rb
---

# Rails Testing Conventions

## Test Execution Syntax

**IMPORTANT: Rails uses MiniTest, not RSpec syntax**

### Correct Syntax
```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/observation_test.rb

# Run specific test by name (use -n flag, NOT ::ClassName#method)
bin/rails test test/models/observation_test.rb -n test_scope_needs_naming

# Run specific system test by name (use -n flag, NOT ::ClassName#method)
bin/rails test test/system/observation_form_system_test.rb -n test_commit_form

# Run with verbose output
bin/rails test test/models/observation_test.rb -v

# Run controller tests
bin/rails test:controllers

# Run with coverage
bin/rails test:coverage
bundle exec rails test:coverage
rake test:coverage
```

### Incorrect Syntax (DO NOT USE)
```bash
# ❌ WRONG - This is RSpec syntax, not Rails
bin/rails test test/models/observation_test.rb::ObservationTest#test_name -v
# ❌ This will cause LoadError: cannot load such file

# ❌ WRONG - This will run the whole system test suite, not the file specified
bin/rails test:system test/system/help_identify_system_test.rb
```

## Test Structure
- Framework: MiniTest (not RSpec)
- Test files: `test/**/*_test.rb`
- Fixtures: `test/fixtures/`
- System tests: Capybara-based

## Common Assertions
- `assert(condition)`
- `assert_equal(expected, actual)`
- `assert_includes(collection, item)`
- `assert_nil(value)`
- `assert_response(:success)`

## Running Specific Test Suites
- All tests: `bin/rails test`
- Controllers: `bin/rails test:controllers`
- Models: `bin/rails test test/models/`
- Coverage: `bin/rails test:coverage`

## Component Test Structure

**IMPORTANT**: Follow this pattern for all Phlex component tests.

### Consolidate Assertions Per Render

Render once, assert many things. Don't create separate test methods that render
the same component with the same configuration.

```ruby
# ✅ Good - one render, multiple assertions
def test_new_form
  html = render_form(model: MyModel.new)

  # Form structure
  assert_html(html, "form[action='/path']")
  assert_html(html, "input[type='submit']")

  # Fields
  assert_html(html, "input[name='model[field1]']")
  assert_html(html, "textarea[name='model[field2]']")

  # Labels and help text
  assert_includes(html, :some_label.l)
end

# ❌ Bad - multiple tests rendering the same thing
def test_form_has_action
  html = render_form(model: MyModel.new)
  assert_html(html, "form[action='/path']")
end

def test_form_has_submit_button
  html = render_form(model: MyModel.new)  # redundant render
  assert_html(html, "input[type='submit']")
end

def test_form_has_field1
  html = render_form(model: MyModel.new)  # redundant render
  assert_html(html, "input[name='model[field1]']")
end
```

### Extract DRY Render Helper

Always extract a private render helper method at the bottom of the test class.
Use keyword arguments with sensible defaults.

```ruby
class MyFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  def test_new_form
    html = render_form(model: MyModel.new)
    # assertions...
  end

  def test_existing_record_form
    html = render_form(model: my_models(:example))
    # assertions...
  end

  def test_with_custom_options
    html = render_form(model: MyModel.new, local: true, back: "/path")
    # assertions...
  end

  private

  def render_form(model:, action: "/test_action", local: false, back: nil)
    render(Components::MyForm.new(
             model,
             user: @user,
             action: action,
             local: local,
             back: back
           ))
  end
end
```

### When to Create Separate Tests

Create separate test methods when:
- Different model states (new vs existing record)
- Different configuration flags that change behavior significantly
- Testing negative cases (e.g., `votes: false` renders nothing)

```ruby
# These warrant separate tests - different configurations
def test_new_form
  html = render_form(model: MyModel.new)
  assert_html(html, "input[value='Create']")
end

def test_existing_record_form
  html = render_form(model: existing_record)
  assert_html(html, "input[value='Save']")
end

def test_renders_nothing_when_disabled
  html = render_form(model: MyModel.new, enabled: false)
  assert_equal("", html)
end
```

### Example Files

See these files for good examples of the pattern:
- `test/components/herbarium_form_test.rb`
- `test/components/sequence_form_test.rb`
- `test/components/naming_form_test.rb`
- `test/components/lightbox_caption_test.rb`
