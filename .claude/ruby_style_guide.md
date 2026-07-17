# Mushroom Observer Ruby Style Guide

This document describes general Ruby and project-level coding style
preferences. For Phlex coding conventions, see `.claude/rules/phlex_reference.md`.

## General Ruby Style

### Method Calls with Parentheses

**Always use parentheses for method calls with arguments.**

**This applies to:**
- Ruby code
- Code examples in comments
- Documentation in all files

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

#### Comments and Documentation

Even in comments, use parentheses for method calls to maintain consistency:

```ruby
# Good
#  5) Render the object's log at the bottom of its show page:
#       render(Components::ObjectFooter.new(user: @user, obj: @object))

# Bad
#  5) Render the object's log at the bottom of its show page:
#       render Components::ObjectFooter.new(user: @user, obj: @object)
```

### Phlex Namespacing

**Kit syntax is the default for top-level components** —
`Components::Icon` → `Icon(...)`, `Components::Link` → `Link(...)`,
`Components::Panel` → `Panel(...)`. Reach for the verbose
`render(Components::X.new(...))` / `render(Views::...::X.new(...))`
form only when Kit syntax genuinely isn't available — most commonly,
a nested **view** (`Views::Controllers::<Controller>::<Action>::
<SubView>`), which never gets Kit sugar and has no dispatcher to route
through either way:

```ruby
# Good — top-level component, Kit syntax
Icon(type: :edit)
Link(type: :active, content: title, path: url)

# Good — nested view, no Kit sugar exists, no dispatcher; full
# namespace + render() is the only way to call it
render(Views::Controllers::Observations::Show::CollectionNumbersSection.new(
  obs: @obs, user: @user
))

# Bad — verbose full-namespace render() for a top-level component
# that already has Kit sugar
render(Components::Icon.new(type: :edit))
```

Nested **components** that have a dispatching parent —
`Components::Link::Get`, `Components::Button::Delete` — should be
reached through the parent's Kit-sugar dispatch (`Link(type: :get,
...)`, `Button(type: :delete, ...)`), not called directly, even
though `render(Components::Link::Get.new(...))` is technically
possible. Nested components with no dispatching parent at all (e.g.
`Components::ListGroup::Item`, which isn't a "variant" of anything)
do need the full `render(Components::ListGroup::Item.new(...))` form.

See `.claude/rules/phlex_reference.md`'s "Kit syntax" section for the
full rule, including why nested classes never get Kit sugar and how
to tell when a component should be flattened to the top level to
gain it.

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

### Prefer `.l` over `.t` for plain-text labels

When localizing a Symbol for a plain-text label, button name, flash
message, or anything else that contains no textile markup
(`*bold*`, `_italic_`, `_link_`, `[obj_link]`, etc.), use `.l` —
not `.t`.

`.t` runs the textile parser over the localized string. For plain
text the textile pass is wasted work, and consistency makes it
easier to scan code for places that intentionally render markup.

```ruby
# Good
flash_error(:permission_denied.l)
flash_notice(:project_created_flash.l(title: project.title))
post_button(name: :show_project_join.l, path: ...)
link_to(:BACK.l, observations_path)

# Bad - .t for plain text labels
flash_error(:permission_denied.t)
post_button(name: :show_project_join.t, path: ...)
link_to(:BACK.t, observations_path)
```

**The `Symbol` extension variants** (see `app/extensions/symbol.rb`):

| Method | Behavior | Use for |
|---|---|---|
| `.l`   | localize (plain) | labels, buttons, flash messages, anything without markup |
| `.t`   | localize + textilize, no paragraphs, no obj links | inline copy with `*bold*`/`_italic_` but no links or paragraph breaks |
| `.tl`  | + obj links | inline copy that should auto-link `_observation_123_`-style references |
| `.tp`  | + paragraphs | body copy that needs paragraph wrapping but no auto-links |
| `.tpl` | + paragraphs + obj links | body copy with paragraphs and auto-links (mailer bodies, project summaries) |

**Defaults and edge cases:**
- New code defaults to `.l` unless the locale string actually
  contains textile markup. If unsure, grep the key in
  `config/locales/en.txt` and check the value.
- When editing a file for any other reason, opportunistically
  flip obvious `.t` → `.l` calls on plain-text labels. Don't
  start a wide sweep just for this — fold it into work you're
  already doing.
- For `flash_notice` / `flash_error` / `flash_warning` /
  `post_button(name: ...)` / `link_to`-style label args,
  almost always `.l`.
- Strings rendered into a paragraph or textile context (mailer
  body templates, project summaries, comments, help blocks) keep
  their `.tp` / `.tpl` / `.t` variant.

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
1. **Always use parentheses** for method calls
2. **Use Kit syntax for top-level components** (`Icon(...)`, `Link(...)`); full namespace + `render()` only when Kit sugar isn't available (nested views, non-dispatched nested components)
3. **Use Rails-preferred assertions** (`assert_no_match`, `assert_not_equal`, etc.) instead of MiniTest refute methods
4. **Run the full test suite** before creating any PR with production Rails code changes
5. **Edit `en.txt` for text strings**, run `rails lang:update`, never commit `.yml` files
6. **Use `.l` for plain-text labels**, reserve `.t` / `.tp` / `.tpl` for strings that contain textile markup
7. **All new code must pass RuboCop** - refactor instead of disabling cops
