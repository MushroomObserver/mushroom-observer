# Mushroom Observer Project Configuration

## Session Start Protocol

**REQUIRED**: At the start of each new session, read `.claude/settings.local.json` and confirm the loaded output style by stating:
```
Output style: <value-from-outputStyle-field>
```

This verifies that `.claude/settings.local.json` was loaded correctly and confirms adherence to the style guidelines.

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

- Run RuboCop: `bundle exec rubocop`
- Avoid over-engineering: only implement requested changes
- Prefer editing existing files over creating new ones
- Follow existing patterns in the codebase
- Migration to Phlex components is ongoing

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
