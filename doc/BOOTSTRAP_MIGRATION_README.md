# Bootstrap Migration Documentation

## Overview

This directory contains complete documentation for migrating Mushroom Observer from Bootstrap 3 to Bootstrap 4 using a parallel systems approach.

## Documentation Index

### For Developers

1. **[Migration Guide](./BOOTSTRAP_MIGRATION_GUIDE.md)** - START HERE
   - Overview of migration strategy
   - Setup instructions
   - Component migration order (10 phases)
   - Testing methodology for each component
   - Rollback procedures
   - Common issues and solutions
   - Timeline and resources

2. **[Migration Checklist](./BOOTSTRAP4_MIGRATION_CHECKLIST.md)** - TRACK PROGRESS
   - Comprehensive checklist for all components
   - Pre-migration setup tasks
   - Phase-by-phase component checklist
   - Testing checklist (cross-browser, responsive, themes)
   - Cleanup and final steps
   - Sign-off requirements

3. **[Breaking Changes Reference](./BOOTSTRAP4_BREAKING_CHANGES.md)** - QUICK REFERENCE
   - Detailed catalog of all BS3 → BS4 changes
   - Organized by component type
   - Code examples (before/after)
   - Impact ratings (HIGH/MEDIUM/LOW)
   - Migration commands (grep patterns for finding usage)
   - Summary checklist of must-change items

4. **[Bootstrap 4 Theme Mapping](./BOOTSTRAP4_THEME_MAPPING.md)** - THEME REFERENCE
   - How MO theme variables map to Bootstrap 4
   - Complete variable mapping tables
   - Unmapped variables explained
   - Import order requirements
   - Migration strategy for themes

5. **[Theme System Analysis](./MO%20Theme%20System%20Analysis.md)** - BACKGROUND
   - Original analysis that led to standardization
   - Phases 1-6 descriptions
   - Overall theme system architecture

## Quick Start

### For First-Time Setup

```bash
# 1. Ensure Phases 1-5 are complete
script/validate_themes.rb  # Should show 121/121 for all themes

# 2. Read the Migration Guide
open doc/BOOTSTRAP_MIGRATION_GUIDE.md

# 3. Install Bootstrap 4
# Add to Gemfile: gem 'bootstrap', '~> 4.6.2'
bundle install

# 4. Create feature branch
git checkout -b bootstrap4-migration

# 5. Start with Phase 1 (Foundation)
# See Migration Guide for details
```

### For Testing Bootstrap 4

```bash
# 1. Edit Gemfile to use Bootstrap 4 gem
# Comment out: gem 'bootstrap-sass', '~> 3.4.1'
# Uncomment: gem 'bootstrap', '~> 4.6.2'
bundle install

# 2. Edit app/assets/stylesheets/mushroom_observer_migration.scss
# Comment out Bootstrap 3 imports
# Uncomment Bootstrap 4 imports

# 3. Compile assets
bundle exec rails assets:precompile RAILS_ENV=development

# 4. Start server
bundle exec rails server

# 5. Test in browser
open http://localhost:3000
```

### For Switching Back to Bootstrap 3

```bash
# 1. Edit Gemfile to use Bootstrap 3 gem
# Uncomment: gem 'bootstrap-sass', '~> 3.4.1'
# Comment out: gem 'bootstrap', '~> 4.6.2'
bundle install

# 2. Edit app/assets/stylesheets/mushroom_observer_migration.scss
# Uncomment Bootstrap 3 imports
# Comment out Bootstrap 4 imports

# 3. Recompile
bundle exec rails assets:precompile RAILS_ENV=development

# 4. Restart server
```

## Migration Phases

The migration is organized into 10 phases that build on each other:

| Phase | Components | Priority | Estimated Time |
|-------|------------|----------|----------------|
| 1 | Foundation (typography, colors, spacing) | Critical | 1-2 weeks |
| 2 | Forms | High | 1 week |
| 3 | Buttons | High | 1 week |
| 4 | Navigation | High | 1 week |
| 5 | Layout Components (cards, list groups) | Medium | 1 week |
| 6 | Content Display (tables, pagination, badges, alerts) | Medium | 1 week |
| 7 | Interactive Components (modals, dropdowns, tooltips) | Medium | 1 week |
| 8 | Grid System | Low | 1 week |
| 9 | Specialized Components (carousels, custom MO components) | Low | 1 week |
| 10 | Testing & Cleanup | Critical | 2-3 weeks |

**Total Estimated Time:** 12 weeks (3 months)

## Key Files

### Stylesheets

- `app/assets/stylesheets/mushroom_observer_migration.scss` - Parallel system stylesheet (toggle via manual commenting)
- `app/assets/stylesheets/mo/_map_theme_to_bootstrap4.scss` - BS4 variable mapping
- `app/assets/stylesheets/mo/_map_theme_vars_to_bootstrap_vars.scss` - BS3 mapping (current)

### Scripts

- `script/validate_themes.rb` - Validates all themes have required variables

### Documentation

- `doc/BOOTSTRAP_MIGRATION_GUIDE.md` - Comprehensive migration guide
- `doc/BOOTSTRAP4_MIGRATION_CHECKLIST.md` - Progress tracking checklist
- `doc/BOOTSTRAP4_BREAKING_CHANGES.md` - Breaking changes reference
- `doc/BOOTSTRAP4_THEME_MAPPING.md` - Theme variable mapping

## Migration Strategy

### Parallel Systems Approach

**IMPORTANT:** Bootstrap 3 and 4 gems **cannot be installed simultaneously**. The parallel approach uses:
1. **Gemfile-level toggling** - Only one Bootstrap gem installed at a time
2. **Manual stylesheet commenting** - Toggle which Bootstrap imports are active
3. **Git worktrees for side-by-side testing** - Separate checkouts with different gems

Toggle between versions:

```scss
// In mushroom_observer_migration.scss
// BOOTSTRAP 3 (comment/uncomment these three lines)
@import "bootstrap-sprockets";
@import "mo/map_theme_vars_to_bootstrap_vars";
@import "bootstrap";

// BOOTSTRAP 4 (comment/uncomment these two lines)
// @import "mo/map_theme_to_bootstrap4";
// @import "bootstrap";
```

**Note:** Sass doesn't allow `@import` inside `@if` blocks, so manual commenting is required.

### Benefits

1. **Gradual Migration** - Components can be migrated one at a time
2. **Easy Testing** - Toggle between versions to compare
3. **Lower Risk** - Can revert individual components if needed
4. **Continuous Deployment** - Don't need to wait for complete migration
5. **Theme Compatibility** - Same theme variables work with both versions

## Testing Strategy

### Three Levels of Testing

1. **Component-Level** - Test each migrated component individually
   - Visual comparison (screenshots)
   - Functional testing (all interactions)
   - All themes tested
   - All device sizes tested

2. **Page-Level** - Test complete pages after component migration
   - All page types (index, show, forms, etc.)
   - User flows (observation creation, name search, etc.)
   - Theme switching

3. **System-Level** - Final comprehensive testing
   - Automated test suite
   - Cross-browser testing
   - Performance testing
   - Accessibility testing

### Side-by-Side Testing

Run both Bootstrap versions simultaneously using git worktrees:

```bash
# Create two separate working directories
git worktree add ../mo-bs3 HEAD
git worktree add ../mo-bs4 HEAD

# Terminal 1: Bootstrap 3
cd ../mo-bs3
# Ensure Gemfile has bootstrap-sass active
bundle install
# Ensure mushroom_observer_migration.scss has BS3 imports uncommented
bundle exec rails assets:precompile RAILS_ENV=development
bundle exec rails server -p 3000

# Terminal 2: Bootstrap 4
cd ../mo-bs4
# Edit Gemfile to use bootstrap gem
bundle install
# Ensure mushroom_observer_migration.scss has BS4 imports uncommented
bundle exec rails assets:precompile RAILS_ENV=development
bundle exec rails server -p 3001
```

Open both in browser windows and compare.

## Common Workflows

### Starting a Component Migration

```bash
# 1. Create feature branch
git checkout -b bs4-component-name

# 2. Take Bootstrap 3 screenshots
# Ensure Gemfile has bootstrap-sass gem active
# Ensure mushroom_observer_migration.scss has BS3 imports uncommented
# Take screenshots, document HTML

# 3. Update component code
# Edit views, helpers, CSS as needed

# 4. Test with Bootstrap 4
# Edit Gemfile to use bootstrap gem
# Edit mushroom_observer_migration.scss to use BS4 imports
bundle install
bundle exec rails assets:precompile RAILS_ENV=development
# Test, take screenshots

# 5. Compare and fix issues
diff screenshots/bs3/ screenshots/bs4/

# 6. Document changes
# Create doc/migration-notes/component-name.md

# 7. Commit
git commit -m "Migrate component-name to Bootstrap 4"
```

### Testing a Specific Component

```bash
# 1. Enable Bootstrap 4
# Edit Gemfile to use bootstrap gem
bundle install
# Edit mushroom_observer_migration.scss to use BS4 imports

# 2. Recompile
bundle exec rails assets:precompile RAILS_ENV=development

# 3. Navigate to component
# Test all states, sizes, themes

# 4. Document issues
# Fix or create tracking issue
```

### Reverting a Problem

```bash
# Quick revert - switch back to Bootstrap 3
# Edit Gemfile to use bootstrap-sass gem
bundle install
# Edit mushroom_observer_migration.scss to use BS3 imports
bundle exec rails assets:precompile RAILS_ENV=development

# Or revert code changes
git revert <commit-hash>

# Or discard feature branch
git checkout main
git branch -D bs4-component-name
```

## Troubleshooting

### Assets Not Compiling

```bash
# Clear cache
bundle exec rails assets:clobber

# Recompile
bundle exec rails assets:precompile RAILS_ENV=development

# Check for syntax errors
bundle exec sass --check app/assets/stylesheets/Agaricus.scss
```

### Both Bootstrap Gems Installed Error

```bash
# Error: "already initialized constant Bootstrap::VERSION"
# or "1rem and 12px have incompatible units"
#
# Cause: Both bootstrap-sass and bootstrap gems installed simultaneously
#
# Fix: Edit Gemfile to have only ONE gem active:
# Comment out gem 'bootstrap-sass', '~> 3.4.1'
# OR comment out gem 'bootstrap', '~> 4.6.2'
bundle install
```

### Missing Bootstrap 4 Gem

```bash
# Install
# Add to Gemfile: gem 'bootstrap', '~> 4.6.2'
bundle install
```

### Styles Look Wrong

1. Check Bootstrap version is correct
2. Verify theme variables mapping
3. Check for class name changes (see Breaking Changes doc)
4. Look for conflicting custom CSS
5. Test with default theme to isolate issue

## Getting Help

1. **Check Documentation** - Start with Migration Guide
2. **Search Breaking Changes** - Common issues documented
3. **Review Migration Notes** - See how others solved similar issues
4. **Bootstrap 4 Docs** - Official reference
5. **Git History** - See how similar components were migrated
6. **Ask Team** - Contact Nathan Wilson (@mo-nathan)

## Success Criteria

Migration is complete when:

- [ ] All components work in Bootstrap 4
- [ ] All 8 themes tested and working
- [ ] All automated tests pass
- [ ] Visual regression tests pass
- [ ] Performance acceptable
- [ ] No console errors
- [ ] Cross-browser tested
- [ ] Mobile responsive works
- [ ] Accessibility maintained
- [ ] Documentation complete
- [ ] Bootstrap 3 removed

## Resources

### Official Documentation

- [Bootstrap 4 Documentation](https://getbootstrap.com/docs/4.6/)
- [Bootstrap 4 Migration Guide](https://getbootstrap.com/docs/4.6/migration/)
- [Bootstrap 4 Theming](https://getbootstrap.com/docs/4.6/getting-started/theming/)

### Tools

- [Sassmeister](https://www.sassmeister.com/) - Test SCSS online
- [ImageMagick](https://imagemagick.org/) - Screenshot comparison
- Chrome DevTools - Responsive testing
- [Lighthouse](https://developers.google.com/web/tools/lighthouse) - Performance/accessibility

### GitHub Issues

- [#3613 - Theme System Standardization](https://github.com/MushroomObserver/mushroom-observer/issues/3613)
- [#3619 - Phase 6: Migration Path](https://github.com/MushroomObserver/mushroom-observer/issues/3619)

## Contact

**Lead:** Nathan Wilson (@mo-nathan)

**Questions?** Open an issue or ask in team chat.

---

Last Updated: 2025-12-19
