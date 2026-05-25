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
```

**Note:** Coverage reports are generated automatically by default using SimpleCov.

### Incorrect Syntax (DO NOT USE)
```bash
# ❌ WRONG - This is RSpec syntax, not Rails
bin/rails test test/models/observation_test.rb::ObservationTest#test_name -v
# ❌ This will cause LoadError: cannot load such file

# ❌ WRONG - This will run the whole system test suite, not the file specified
bin/rails test:system test/system/help_identify_system_test.rb
```

## Finding Records After Creation

**Never use `Model.last` (or `Model.order(...).last`) to find a record just
created by a test.** In parallel test runs, another worker may insert a record
with a higher ID between the creation and the lookup, returning the wrong object
and causing a silent, flaky failure.

**Instead, look up by known attributes:**

```ruby
# ❌ Wrong — races with parallel workers
herbarium = Herbarium.last
comment   = Comment.last

# ✅ Correct — find by attributes the test controls
herbarium = Herbarium.find_by(name: params[:herbarium][:name].strip_html.strip)
comment   = Comment.find_by(summary: "Known Summary", target: obs)
```

Always add `assert_not_nil(record, "Cannot find ModelName")` immediately after
the lookup so a nil return fails with a clear message instead of a cryptic
`NoMethodError`.

**Safe uses of `.last`** (not a race condition):
- Association-scoped: `obs.namings.order(:id).last` — scoped to a specific parent
- In-process queues: `ActionMailer::Base.deliveries.last`
- Fixture lookups where no record is being created (though a fixture name is clearer)

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

## FORBIDDEN: assertions against rendered HTML body

**Never** assert on rendered HTML markup with regex or by probing the
raw response body. This is an absolute rule — not "where convenient,"
not "in this file only."

```ruby
# ❌ FORBIDDEN — regex on @response.body
assert_match(/<input name="foo"/, @response.body)
assert_no_match(/error/, @response.body)

# ❌ FORBIDDEN — aliasing @response.body to a local doesn't make it ok
body = @response.body
assert_match(/something/, body)

# ❌ FORBIDDEN — `assert_select("body", text: /.../)` defeats the point.
# The "body" selector matches the entire <body> element, so the regex
# still scans the full document text and failure messages still dump
# the whole body. Use a SPECIFIC element selector.
assert_select("body", text: /something/)

# ❌ FORBIDDEN in component tests — regex on the rendered string
assert_match(/<a class="btn"/, html)

# ❌ FORBIDDEN — substring check on raw HTML
assert_includes(@response.body, "<label>Email</label>")
assert_includes(html, :some_label.l)  # text lives in SOME element — find it
```

Use the selector-based helpers instead:

```ruby
# ✅ Controller tests — assert_select with a SPECIFIC selector
assert_select("input[name='foo']")
assert_select("#error_explanation", count: 0)
assert_select("a[href*=?]", profile_path(user))
assert_select("label", text: :some_label.l)

# ✅ Component tests — assert_html (Nokogiri CSS)
assert_html(html, "input[name='model[field]']")
assert_html(html, ".btn-primary", text: :submit.l)
assert_html(html, "label", text: :some_label.l)
assert_no_html(html, "#modal_overlay")
```

Translation strings are not an exception. Every visible string lives
in some element — a `<p>`, `<button>`, `<label>`, `<h3>`, `.alert`,
`.flash-notice`, etc. Find that element and use it as the selector.
If you genuinely cannot identify the wrapping element, read the
component / view to find it. "I don't know what element it's in" is
not a reason to fall back to a body-wide assertion.

**Why this matters:**

1. **Failure messages.** A failed `assert_match(/foo/, @response.body)`
   dumps the entire response body into the log — useless CI signal.
   A failed `assert_select("input[name='foo']")` says exactly that:
   "0 matches for `input[name='foo']`." Actionable.
2. **Robustness.** Whitespace changes, attribute reordering, and HTML
   encoding can all silently break a regex without changing the
   rendered page. CSS selectors are stable against those.
3. **Intent.** `assert_select("input[name='foo']")` says what you
   actually mean — "there's an input named foo." A regex like
   `/<input name="foo"/` is a literal-text accident waiting to break.
4. **Speed (sometimes).** For controller tests with multiple
   assertions on the same response, `assert_select` parses once via
   Nokogiri and reuses the DOM, while each `assert_match` re-scans the
   full body string. (For component tests, `assert_html` re-parses on
   each call — the speed argument doesn't apply there.)

**Non-HTML payloads.** This rule is about rendered HTML. For JSON use
`response.parsed_body`. For redirects use `assert_redirected_to`. For
CSV parse it. Never reach for raw `@response.body` in those cases
either.

**Pre-extracted text is fine.** If you've already pulled a small
element's text out via a selector (e.g.
`css_select(".rss-what").text`), regex / includes against that
extracted string is fine — the haystack is one element's text, not
the whole document.

**Cleanup expectation.** If you find existing forbidden patterns
near your edit, fix them. Don't leave them in place "because the PR
isn't about that" — every PR that touches a test file is the right
place to clean up whatever forbidden assertions live in it.

## Running Specific Test Suites
- All tests: `bin/rails test`
- Controllers: `bin/rails test:controllers`
- Models: `bin/rails test test/models/`
- Coverage: `bin/rails test:coverage`

## Verify per-file coverage on every open PR

The goal isn't "the lines I added are covered" — it's **"every Ruby
file I touched is at 100% line coverage, before AND after my change."**
Diff coverage (the coveralls bot's headline percentage) only counts
the lines you added or modified; it'll happily report 100% on a PR
that leaves unrelated code in the touched files uncovered.

What to do, after the coveralls bot comments on the PR:

1. Pull the per-file numbers from the build's `source_files.json`:

    ```bash
    BUILD_ID=$(gh pr view <PR> --json comments \
      --jq '.comments[] | select(.author.login=="coveralls") | .body' |
      grep -oE "coveralls.io/builds/[0-9]+" | tail -1 |
      grep -oE "[0-9]+$")

    gh pr view <PR> --json files \
      --jq '.files[] | select(.changeType!="DELETED") | .path' |
      grep -E '\.rb$' |
      while read -r path; do
        curl -s "https://coveralls.io/builds/${BUILD_ID}/source_files.json?per_page=1000" |
          python3 -c "
import sys, json, os
d = json.load(sys.stdin)
src = json.loads(d['source_files']) if isinstance(d['source_files'], str) else d['source_files']
f = next((x for x in src if x['name'] == os.environ['P']), None)
if f:
  cov, rel, miss = f['covered_line_count'], f['relevant_line_count'], f['missed_line_count']
  pct = 100.0 * cov / rel if rel else 0
  flag = '' if miss == 0 else f'  MISSED {miss}'
  print(f\"{os.environ['P']}: {cov}/{rel} ({pct:.1f}%){flag}\")
else:
  print(f\"{os.environ['P']}: <not instrumented>\")
" P="$path"
      done
    ```

2. **Every Ruby file in the PR should report 100% coverage.** ERB,
   config, Markdown, etc. show up as `<not instrumented>` — that's
   expected; SimpleCov only instruments Ruby.

3. **Every PR should lever coverage upward.** If a touched file is
   below 100%, fix the gap in the same PR — even if the uncovered
   lines were already missed on `main` before your edit. Either add
   tests that exercise the uncovered branches, or remove the dead
   code. The reasoning: a PR that touches a file is the right place
   to bring it to 100%; deferring it means the gap survives every
   future PR that touches the file until someone finally signs up to
   fix it. Touch it, finish it.

Why both numbers matter:

- **Diff coverage** confirms your changes are tested. Easy to game
  (write tests that touch every added line without exercising real
  behavior).
- **Per-file coverage** confirms the file as a whole is testable.
  A file at 100% has every method, every branch, every guard reachable
  from a test — which is what gives you confidence that the next
  refactor won't silently drop a behavior.

For local checking before pushing, SimpleCov writes `coverage/index.html`
and `coverage/.last_run.json` after each test run. Open the HTML report
or jq the JSON to find missed lines on any file.

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

  # Fields — ALWAYS include [name='...'] to verify param structure
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

### Always Assert Field `name` Attributes

**REQUIRED**: Every form field assertion must include the `name` attribute.
The `name` is the contract between the form and the controller's `params`
parsing. Asserting only element existence (e.g., `input[type='file']`)
will not catch param namespace mismatches that silently break form
submission.

```ruby
# ❌ Bad - won't catch param structure bugs
assert_html(html, "input[type='file']")
assert_html(html, "textarea[rows='10']")

# ✅ Good - verifies the form-to-controller contract
assert_html(html, "input[type='file'][name='project[upload][image]']")
assert_html(html, "textarea[name='email[message]'][rows='10']")
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

## Debugging "Form Does Nothing"

When a form renders correctly but doesn't submit in the browser:

1. **Write a system test first** — controller tests bypass JS and DOM
   parsing, so they won't reproduce browser-only issues.
2. **Check for nested forms** — inspect rendered HTML for `<form>`
   inside `<form>`. This is the #1 cause. See "Nested `<form>` Elements"
   in `.claude/phlex_style_guide.md`.
3. **Check Turbo interference** — MO uses `Turbo.config.forms.mode =
   "optin"`. Forms without `data-turbo="true"` should submit normally.
   Forms with `data-turbo="true"` need a Turbo-compatible server
   response. `ApplicationForm` defaults to `local: true` (no Turbo).
4. **Check for JS errors** — Cuprite can capture console errors.
5. **Try `form.submit()` via JS** — if programmatic submit works but
   button click doesn't, the button is likely outside the form in the
   DOM tree (nested form issue).

## Bullet N+1 Detection in System Tests

System tests run through the full Rails stack with Bullet enabled.
Bullet raises `UnoptimizedQueryError` for N+1 queries. When adding
`.includes()` to fix these, add all associations that will be accessed
during the request (including the redirect target page). Common
observation associations: `:field_slip, :occurrence, :user, :location,
:name, :thumb_image`.

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
