# Mushroom Observer

Community science platform for mushroom identification and observation.

## Session Start Protocol

**REQUIRED**: At the start of each new session:

1. Load the default output style from `.claude/output-styles/professional-direct.md`
2. If `.claude/settings.local.json` exists, read it and override with the `outputStyle` value if present
3. If `.claude/developer.json` exists, read the `branchPrefix` value for git branch naming
4. Confirm the loaded output style by stating:
   ```
   Output style: <style-name>
   ```

## Build & Run

```bash
# Install dependencies
bundle install

# Start development server
bin/rails server

# Rails console
bin/rails console

# View routes
bin/rails routes
```

## Test

Framework: **MiniTest** (not RSpec). System tests use **Capybara + Cuprite**.

```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/observation_test.rb

# Run single test by name (use -n flag, NOT RSpec-style syntax)
bin/rails test test/models/observation_test.rb -n test_scope_needs_naming

# Run multiple specific tests — use a regex; multiple -n flags drop all but last
bin/rails test test/models/name_test.rb -n /test_name_(spaceship_operator|sort_order)/

# Run tests in a directory
bin/rails test test/components/

# Run test methods which match regexp
bin/rails test r test/controllers/observations_controller_show_test.rb -n /login/

# Run with verbose output
bin/rails test test/models/observation_test.rb -v

```

### CRITICAL: System Test Syntax

```bash
# CORRECT - runs only the specified system test file
bin/rails test test/system/observation_naming_system_test.rb

# WRONG - runs ALL system tests, ignores the file argument
bin/rails test:system test/system/observation_naming_system_test.rb
```

## Lint

```bash
# Check for violations
bundle exec rubocop path/to/file.rb --format simple

# Auto-correct
bundle exec rubocop path/to/file.rb --autocorrect-all
```

All new code must pass RuboCop. Always refactor Metrics violations (`AbcSize`,
`MethodLength`, `ClassLength`, `CyclomaticComplexity`,
`PerceivedComplexity`) — do not disable cops.

### RuboCop Workflow

After creating or modifying Ruby files:

1. Run: `bundle exec rubocop path/to/file.rb --format simple`
2. Auto-correct: `bundle exec rubocop path/to/file.rb --autocorrect-all`
3. Manually fix remaining violations (especially line length and metrics)
4. Verify clean: output should show "no offenses detected"

### Refactoring Strategies

1. **Extract methods** — break large methods into smaller, focused methods
2. **Extract conditional logic** into predicate methods
3. **Extract data structures** — move complex hashes/arrays to separate
   methods
4. **Use guard clauses** to reduce nesting

Good examples: `app/components/image_vote_section.rb`,
`app/components/lightbox_caption.rb`

## Code Style

- **80 character line limit** in both Ruby and ERB files
- **Always use parentheses** for method calls with arguments (Ruby and ERB)
- **Use `tag.element_name`** in ERB templates, never `content_tag`
- **Use full namespaces** for components: `Components::ClassName`
- **Prefer Phlex helpers** over Rails `tag` helpers in components
- **Double-quoted strings** (enforced by RuboCop)

See `.claude/ruby_style_guide.md` for detailed Ruby and ERB conventions.
See `.claude/phlex_style_guide.md` for Phlex component conventions.
See `.claude/rules/testing.md` for test structure and component test patterns.

## Git Workflow

- Create feature branches from `main`
- **Branch naming**: `<prefix>-feature-description`
  - Prefix from `.claude/developer.json` (`branchPrefix` field), or derived
    from `git config user.name` (e.g., "Nathan Wilson" -> `nw`)
  - Use kebab-case: `njw-fix-1234-description`
  - **Setup**: Create `.claude/developer.json` with
    `{"branchPrefix": "your-initials"}` (git-ignored)
- Commit messages include Claude Code attribution
- Create PRs via `gh pr create` with detailed descriptions
- Link PRs to issues with `Fixes #issue_number`

## Architecture

```
app/
  models/          # ActiveRecord models (MySQL via Trilogy)
  classes/         # Ruby POROs, including FormObject for Phlex forms
  controllers/     # Rails controllers
  components/      # Phlex components (migration from ERB in progress)
  jobs/            # ActiveJobs
  views/           # ERB templates (being replaced by components)
  javascript/      # Stimulus controllers, Turbo, importmap
  helpers/         # View helpers (being migrated to components)
test/              # MiniTest suite
  fixtures/        # Test fixtures
  system/          # Capybara system tests (Cuprite driver)
  components/      # Phlex component tests
```

**Stack**: Ruby 3.3, Rails 7.2, MySQL, Phlex 2.0+, Stimulus + Turbo,
importmap, GitHub Actions CI (4 parallel workers)

**Key patterns**:
- `User.current` for current user tracking when @user is not available
- `observation_views` table for view stats
- Custom i18n system: `en.txt` -> `en.yml` translation files.
  **NEVER edit `config/locales/en.yml` directly.** Edit `en.txt` then
  run `rails lang:update`.
- Avoid over-engineering — implement only requested changes
- Prefer editing existing files over creating new ones
