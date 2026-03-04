# Supplementary Instructions

See the root `CLAUDE.md` for primary project configuration, commands, and
conventions. This file contains additional details.

## Refactoring Metrics Violations

Always refactor code that has Metrics violations (`AbcSize`, `MethodLength`,
`ClassLength`, `CyclomaticComplexity`, `PerceivedComplexity`).

Strategies:

1. **Extract methods** — break large methods into smaller, focused methods
2. **Extract conditional logic** into predicate methods
3. **Extract data structures** — move complex hashes/arrays to separate methods
4. **Use guard clauses** to reduce nesting

Good examples in this codebase:
- `app/components/image_vote_section.rb`
- `app/components/lightbox_caption.rb`

## RuboCop Workflow

After creating or modifying Ruby files:

1. Run: `bundle exec rubocop path/to/file.rb --format simple`
2. Auto-correct: `bundle exec rubocop path/to/file.rb --autocorrect-all`
3. Manually fix remaining violations (especially line length and metrics)
4. Verify clean: output should show "no offenses detected"
