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

## Debugging Phlex Component Conversions

**CRITICAL: This is the FIRST step for ALL Phlex conversion debugging.**

When converting ERB/helpers to Phlex components, the ONLY thing changing is the
HTML output. Therefore, ALL bugs come from HTML differences. Comparing HTML
output will eliminate 90% of debugging work.

### The HTML Diff Technique

**Before reading code or guessing at problems, ALWAYS diff the HTML output.**

#### Step 1: Create "Old" Component Versions

Create copies of the original components with `Old` suffix that use the legacy
implementation. Keep these ON THE SAME BRANCH for easy comparison:

```ruby
# app/components/my_component_old.rb
class Components::MyComponentOld < Components::Base
  # Copy the original implementation exactly
  # This renders using the old ERB/helper approach
end
```

For component hierarchies (parent → child → grandchild), create Old versions
of ALL components in the chain:

```ruby
# If refactoring FormCarousel → FormCarouselItem → FormImageFields
# Create ALL of these:
app/components/form_carousel_old.rb
app/components/form_carousel_item_old.rb
app/components/form_image_fields_old.rb
```

#### Step 2: Write an HTML Diff Test

Create a test that renders BOTH versions with identical data:

```ruby
# /tmp/html_diff_test.rb
require "test_helper"

class HtmlDiffTest < ComponentTestCase
  def test_diff_component_html
    # Setup identical test data
    user = users(:mary)
    model = models(:example)

    # OLD version
    old_html = render(Components::MyComponentOld.new(
      user: user,
      model: model
    ))
    File.write("/tmp/component_old.html", old_html)

    # NEW version
    new_html = render(Components::MyComponent.new(
      user: user,
      model: model
    ))
    File.write("/tmp/component_new.html", new_html)

    puts "Old: #{old_html.length} chars, New: #{new_html.length} chars"
    puts "Diff: diff /tmp/component_old.html /tmp/component_new.html"
    assert true
  end
end
```

#### Step 3: Run and Diff

```bash
# Generate the HTML files
bin/rails test /tmp/html_diff_test.rb

# Format for readable diff (optional)
python3 -c "
import re
for name in ['old', 'new']:
    with open(f'/tmp/component_{name}.html') as f:
        html = re.sub(r'><', r'>\n<', f.read())
    with open(f'/tmp/component_{name}_fmt.html', 'w') as f:
        f.write(html)
"

# View the diff
diff /tmp/component_old_fmt.html /tmp/component_new_fmt.html
```

#### Step 4: What to Look For in the Diff

**Stimulus/JS-critical differences** (will break functionality silently):
- `data-controller` - Must match exactly
- `data-*-target` - Stimulus targets, exact match required
- `data-action` - Event handlers
- `data-*` - Any custom data attributes
- Element `id` attributes - JS uses `getElementById`
- Form field `name` attributes - Rails param parsing depends on these

**Common causes of "empty" or "missing" content:**
- Guard clause returning early (`return unless @prop`)
- Block not yielding content properly
- Namespace/field not rendering (check length difference)

**Length differences are diagnostic:**
- Much shorter new HTML = something isn't rendering
- Much longer new HTML = duplicate rendering or extra wrappers

### Why This Works

1. **JS/Stimulus hasn't changed** - If it worked before, the HTML is the problem
2. **Visual inspection of code misses subtleties** - A missing `.to_s` or wrong
   attribute name is easy to overlook in code but obvious in HTML diff
3. **No JS errors to diagnose** - Stimulus fails silently when targets/data
   attributes are wrong
4. **Exact output comparison** - Shows what actually renders, not what you
   think renders

### Example: Finding a Date Bug

When dates showed "today" instead of the image date:

```html
<!-- OLD (correct): day 11 selected -->
<option value="11" selected="selected">11</option>

<!-- NEW (wrong): day 6 selected (today) -->
<option value="6" selected>6</option>
```

The diff immediately revealed the bug: DateField wasn't using the passed
`value:` attribute. Reading the code would have taken much longer to spot.
