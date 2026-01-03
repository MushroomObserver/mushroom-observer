# Mushroom Observer Project Configuration

## Session Start Protocol

**REQUIRED**: At the start of each new session:

1. Load the default output style from `.claude/output-styles/professional-direct.md`
2. If `.claude/settings.local.json` exists, read it and override with the `outputStyle` value if present
3. Confirm the loaded output style by stating:
   ```
   Output style: <style-name>
   ```

This ensures consistent communication style with optional per-developer customization.

## Project Information

**Project**: Mushroom Observer - Community science platform for mushroom identification and observation
**Framework**: Ruby on Rails 7.2
**Testing**: MiniTest (not RSpec)
**Main Branch**: `main`
**Component System**: Migrating from Rails view helpers to Phlex components

## Testing Conventions

See `.claude/rules/testing.md` for detailed Rails testing syntax and conventions.

**Quick Reference**:
- Run specific test: `bin/rails test <file> -n <test_name>`
- Run test file: `bin/rails test <file>`
- Run all tests: `bin/rails test`
- Coverage: `bin/rails test:coverage`

**Important**: Use `-n` flag for test names, NOT RSpec-style `::ClassName#method` syntax.

### CRITICAL: System Test Syntax

**NEVER** use `bin/rails test:system test/system/file.rb` - this runs ALL system tests, ignoring the specified file.

**ALWAYS** use: `bin/rails test test/system/file.rb`

```bash
# ✅ CORRECT - runs only the specified system test file
bin/rails test test/system/observation_naming_system_test.rb

# ❌ WRONG - runs ALL system tests, ignores the file argument
bin/rails test:system test/system/observation_naming_system_test.rb
```

## Git Workflow

- Create feature branches from `main`
- **Branch naming convention**: `<prefix>-feature-description`
  - Prefix is derived from `git config user.name` (converted to lowercase initials)
  - Can be overridden in `.claude/settings.local.json` with `branchPrefix` setting
  - Example: "Nathan Wilson" → `nw-fix-bug-123` or `njw-add-dark-mode`
  - Use kebab-case for feature description
  - Include issue numbers when applicable: `prefix-fix-1234-description`
- Commit messages include Claude Code attribution
- Create PRs via `gh pr create` with detailed descriptions
- Link PRs to issues with `Fixes #issue_number`

## Code Style

See `.claude/style_guide.md` for detailed Ruby, ERB, and Phlex component style conventions.

**Quick Reference**:
- Run RuboCop: `bundle exec rubocop`
- Always use parentheses for method calls (Ruby and ERB)
- Use full namespaces for components: `Components::ClassName`
- Prefer Phlex helpers over Rails `tag` helpers in components
- All new code must pass RuboCop - refactor instead of disabling cops

**Important**: Avoid over-engineering - only implement requested changes. Prefer editing existing files over creating new ones. Migration to Phlex components is ongoing.

## Common Commands

- Rails console: `bin/rails console`
- Routes: `bin/rails routes`
- Database: Rails migrations in `db/migrate/`
- Assets: `bundle exec rails assets:precompile`

## Architecture Notes

- **Models**: `app/models/` - ActiveRecord models
- **Controllers**: `app/controllers/` - Rails controllers
- **Components**: `app/components/` - Phlex components (migration in progress)
- **Views**: `app/views/` - ERB templates (being replaced by components)
- **JavaScript**: `app/javascript/` - Stimulus controllers, importmap
- **Helpers**: `app/helpers/` - View helpers (being migrated to components)
- **Tests**: `test/` - MiniTest suite

## Database

- Primary: MySQL
- View stats tracked in `observation_views` table
- Users tracked with `User.current` (being phased out)
