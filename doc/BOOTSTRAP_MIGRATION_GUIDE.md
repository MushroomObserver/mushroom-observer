# Bootstrap 3 to 4 Migration Guide

## Overview

This guide covers the migration from Bootstrap 3 to Bootstrap 4 for Mushroom Observer. The migration uses a **staged migration approach** with infrastructure that supports rapid toggling between Bootstrap versions for development and testing.

**Key Constraint:** Bootstrap 3 and 4 gems cannot be installed simultaneously, so the actual production deployment will be a single switchover event after all components are ready.

## Table of Contents

1. [Migration Strategy](#migration-strategy)
2. [Setup Instructions](#setup-instructions)
3. [Component Migration Order](#component-migration-order)
4. [Testing Methodology](#testing-methodology)
5. [Rollback Procedures](#rollback-procedures)
6. [Common Issues](#common-issues)
7. [Resources](#resources)

## Migration Strategy

### Staged Migration with Rapid Toggle Infrastructure

This approach allows **incremental development** while maintaining a **controlled deployment**:

**Development Phase (Component-by-Component):**
1. **Update component HTML/views** to use Bootstrap 4 compatible classes
2. **Add compatibility shims** in custom CSS so components work with both BS3 and BS4
3. **Test each component** by toggling between BS3 and BS4 gems
4. **Commit when component works** with both versions (or is BS4-only after all components ready)
5. **Repeat for all components** until entire application is migration-ready

**Deployment Phase (Single Switchover):**
1. All components are BS4-ready and tested
2. Production deployment switches from bootstrap-sass to bootstrap gem
3. Remove BS3 compatibility shims in cleanup phase

### What This Approach Enables

- ✅ **Incremental development** - Update components one at a time
- ✅ **Rapid testing** - Toggle between BS3/BS4 to compare (requires bundle install)
- ✅ **Lower risk development** - Test each component before moving to next
- ✅ **Theme compatibility** - Same theme variables work with both versions
- ✅ **Controlled deployment** - Production switches only when all components ready
- ✅ **Rollback capability** - Can revert deployment if critical issues found

### What This Approach Does NOT Enable

- ❌ **Gradual production deployment** - Cannot deploy BS4 component-by-component
- ❌ **Parallel runtime** - Cannot run BS3 and BS4 simultaneously in one installation
- ❌ **A/B testing in production** - Deployment is all-or-nothing switchover

**Reality Check:** While development is incremental, the production deployment is still a "big bang" event. This infrastructure reduces risk by ensuring everything is tested before that switchover.

## Setup Instructions

### 1. Understanding Gem Limitations

**IMPORTANT:** Bootstrap 3 and Bootstrap 4 gems **cannot be installed simultaneously**. Both gems:
- Define the same Ruby constants (`Bootstrap::VERSION`)
- Register the same Sass import paths (`@import "bootstrap"`)
- Use incompatible units (pixels vs REMs)

This means you must **toggle at the Gemfile level**, not just the stylesheet level.

### 2. Install Bootstrap 4 Gem

**Edit `Gemfile`** to toggle between Bootstrap versions:

**For Bootstrap 3 (current production):**
```ruby
gem 'bootstrap-sass', '~> 3.4.1'
# gem 'bootstrap', '~> 4.6.2'  # Comment out
```

**For Bootstrap 4 testing:**
```ruby
# gem 'bootstrap-sass', '~> 3.4.1'  # Comment out
gem 'bootstrap', '~> 4.6.2'
```

Then run:
```bash
bundle install
```

**Alternative: Environment Variable Approach (Better for Teams)**

```ruby
# Gemfile
if ENV['BOOTSTRAP_VERSION'] == '4'
  gem 'bootstrap', '~> 4.6.2'
else
  gem 'bootstrap-sass', '~> 3.4.1'  # Default
end
```

Switch versions:
```bash
# Bootstrap 3 (default)
bundle install

# Bootstrap 4
BOOTSTRAP_VERSION=4 bundle install
```

### 3. Toggle Bootstrap Version in Stylesheet

The migration stylesheet uses manual commenting to switch between Bootstrap versions
(Sass doesn't allow `@import` inside `@if` blocks).

Edit `app/assets/stylesheets/mushroom_observer_migration.scss`:

```scss
// BOOTSTRAP 3 (active by default)
@import "bootstrap-sprockets";
@import "mo/map_theme_vars_to_bootstrap_vars";
@import "bootstrap";

// BOOTSTRAP 4 (commented out)
// @import "mo/map_theme_to_bootstrap4";
// @import "bootstrap";  // BS4 version
```

To switch to Bootstrap 4:
1. Comment out the Bootstrap 3 imports
2. Uncomment the Bootstrap 4 imports
3. Recompile assets

### 4. Switch to Migration-Ready Stylesheet (Optional for Testing)

To test the toggle infrastructure:

1. Backup current theme file (e.g., `app/assets/stylesheets/Agaricus.scss`)
2. Modify theme file to import migration stylesheet:

```scss
@import "variables/defaults";
@import "variables/agaricus";
@import "mushroom_observer_migration";  // Instead of mushroom_observer
```

3. Compile assets:
```bash
bundle exec rails assets:precompile RAILS_ENV=development
```

### 4. Enable Bootstrap 4 for Testing

1. Edit `mushroom_observer_migration.scss`:
   - Comment out Bootstrap 3 imports
   - Uncomment Bootstrap 4 imports
2. Recompile assets:
   ```bash
   bundle exec rails assets:precompile RAILS_ENV=development
   ```
3. Test in browser

## Component Migration Order

Migrate components in this order to minimize dependency issues:

### Phase 1: Foundation (Week 1-2)
**Priority: Critical**

- [x] Theme variables (Phase 1-3) ✅ Complete
- [x] Variable mapping (Phase 5) ✅ Complete
- [ ] Typography (body text, headings, paragraphs)
- [ ] Colors (alerts, text utilities)
- [ ] Spacing utilities

**Why first?** These affect everything else. Get the foundation right before building on it.

### Phase 2: Forms (Week 3)
**Priority: High**

- [ ] Text inputs
- [ ] Textareas
- [ ] Select dropdowns
- [ ] Checkboxes and radios
- [ ] Form validation states
- [ ] Input groups
- [ ] Form layouts (horizontal, inline)

**Why second?** Forms are used throughout the app and have significant API changes in BS4.

**Breaking Changes:**
- `.form-control-static` → `.form-control-plaintext`
- `.help-block` → `.form-text`
- Form group no longer requires `.form-group`

### Phase 3: Buttons (Week 4)
**Priority: High**

- [ ] Button styles (.btn-default, .btn-primary, etc.)
- [ ] Button sizes (.btn-sm, .btn-lg)
- [ ] Button groups
- [ ] Dropdown buttons
- [ ] Button states (active, disabled)

**Breaking Changes:**
- `.btn-default` → `.btn-secondary`
- Outline buttons now use `.btn-outline-*` instead of custom classes

### Phase 4: Navigation (Week 5)
**Priority: High**

- [ ] Top navbar
- [ ] Left sidebar navigation
- [ ] Breadcrumbs
- [ ] Tabs
- [ ] Pills

**Breaking Changes:**
- Navbar restructured significantly (`.navbar-default` → `.navbar-light`)
- `.nav-stacked` removed (use `.flex-column`)
- `.navbar-toggle` → `.navbar-toggler`

### Phase 5: Layout Components (Week 6)
**Priority: Medium**

- [ ] Cards (replacing panels)
- [ ] List groups
- [ ] Media objects
- [ ] Responsive utilities

**Breaking Changes:**
- `.panel` → `.card`
- `.panel-heading` → `.card-header`
- `.panel-body` → `.card-body`
- `.panel-footer` → `.card-footer`
- `.thumbnail` removed

### Phase 6: Content Display (Week 7)
**Priority: Medium**

- [ ] Tables
- [ ] Pagination
- [ ] Badges
- [ ] Labels → Badges
- [ ] Alerts
- [ ] Progress bars

**Breaking Changes:**
- `.label` → `.badge`
- Table `.table-condensed` → `.table-sm`
- Badge pill uses `.badge-pill` class

### Phase 7: Interactive Components (Week 8)
**Priority: Medium**

- [ ] Modals
- [ ] Dropdowns
- [ ] Tooltips
- [ ] Popovers
- [ ] Collapse/Accordion

**Breaking Changes:**
- Modal structure changed
- Data attributes renamed (`data-toggle` etc.)
- Some JavaScript event names changed

### Phase 8: Grid System (Week 9)
**Priority: Low**

- [ ] Container layouts
- [ ] Row/column structure
- [ ] Responsive breakpoints
- [ ] Column offsets and ordering

**Breaking Changes:**
- New `-xl` breakpoint added
- `.col-xs-*` → `.col-*`
- `.hidden-*` → `.d-none .d-*-block`
- `.visible-*` removed

### Phase 9: Specialized Components (Week 10)
**Priority: Low**

- [ ] Carousels
- [ ] Jumbotrons
- [ ] Wells → Cards with `.bg-light`
- [ ] Custom MO components

**Breaking Changes:**
- `.well` removed (use `.card` with `.bg-light`)
- Carousel indicators structure changed

### Phase 10: Cleanup (Week 11-12)
**Priority: Low**

- [ ] Remove Bootstrap 3 compatibility shims
- [ ] Remove unused CSS
- [ ] Optimize asset compilation
- [ ] Update documentation
- [ ] Final cross-browser testing

## Testing Methodology

### For Each Component

Follow this checklist for every component you migrate:

#### 1. Pre-Migration Testing (Bootstrap 3 Baseline)

```bash
# Enable Bootstrap 3
# Edit mushroom_observer_migration.scss - ensure BS3 imports uncommented

# Take screenshots
# Document: screenshots/bs3/component-name/
- Desktop (1920x1080)
- Tablet (768x1024)
- Mobile (375x667)

# Test all states
- Default
- Hover
- Active/Focus
- Disabled
- Error/Validation (if applicable)

# Test with all themes
- Agaricus
- Amanita
- Cantharellaceae
- Hygrocybe
- Admin
- Sudo
- BlackOnWhite

# Document current HTML structure
```

#### 2. Update Component

```bash
# Create feature branch
git checkout -b bs4-migrate-component-name

# Update view templates
# Update helper methods
# Update custom CSS if needed
# Add compatibility shims in mushroom_observer_migration.scss if needed
```

#### 3. Post-Migration Testing (Bootstrap 4)

```bash
# Enable Bootstrap 4
# Edit mushroom_observer_migration.scss:
# - Comment out Bootstrap 3 imports
# - Uncomment Bootstrap 4 imports

# Recompile assets
bundle exec rails assets:precompile RAILS_ENV=development

# Take screenshots (same locations as step 1)
# Document: screenshots/bs4/component-name/

# Compare visually
diff screenshots/bs3/component-name/ screenshots/bs4/component-name/

# Test functionality
- Click all buttons
- Submit all forms
- Open all dropdowns
- Test all interactive elements

# Test with all themes (same list as step 1)

# Run automated tests
bundle exec rails test
```

#### 4. Document Differences

Create `doc/migration-notes/component-name.md`:

```markdown
# Component Name Migration

## Visual Changes
- List any visual differences
- Note if acceptable or needs fixing

## HTML Changes
- Old structure
- New structure

## CSS Changes
- Removed classes
- Added classes
- Changed styles

## JavaScript Changes
- Updated event handlers
- New/changed data attributes

## Issues Found
- List any bugs or problems
- Solutions applied

## Testing Checklist
- [ ] Desktop tested
- [ ] Mobile tested
- [ ] All themes tested
- [ ] All states tested
- [ ] Automated tests pass
```

#### 5. Review and Merge

```bash
# If component looks good
git add .
git commit -m "Migrate component-name to Bootstrap 4"

# If issues found
# Fix issues or revert
git checkout main
git branch -D bs4-migrate-component-name
```

### Side-by-Side Testing

For critical components, set up side-by-side comparison.

**IMPORTANT:** Since Bootstrap 3 and 4 gems cannot coexist, you need **separate codebases** with different gems installed:

```bash
# Use git worktrees to create two separate working directories
git worktree add ../mo-bs3 HEAD
git worktree add ../mo-bs4 HEAD

# Terminal 1: Bootstrap 3
cd ../mo-bs3
# Ensure Gemfile has bootstrap-sass gem active
bundle install
# Ensure mushroom_observer_migration.scss has BS3 imports uncommented
bundle exec rails assets:precompile RAILS_ENV=development
bundle exec rails server -p 3000

# Terminal 2: Bootstrap 4
cd ../mo-bs4
# Edit Gemfile to use bootstrap gem instead
# Uncomment: gem 'bootstrap', '~> 4.6.2'
# Comment: gem 'bootstrap-sass', '~> 3.4.1'
bundle install
# Ensure mushroom_observer_migration.scss has BS4 imports uncommented
bundle exec rails assets:precompile RAILS_ENV=development
bundle exec rails server -p 3001
```

Then:
1. Open both in browser windows side-by-side (localhost:3000 and localhost:3001)
2. Navigate through same pages simultaneously
3. Document any differences

### Automated Testing

Run the full test suite after each component:

```bash
# Unit tests
bundle exec rails test

# System/integration tests
bundle exec rails test:system

# JavaScript tests (if applicable)
npm test

# Rubocop
rubocop

# Theme validation
script/validate_themes.rb
```

## Rollback Procedures

### If a Component Has Issues

#### Option 1: Fix Forward (Preferred)

```bash
# Identify the issue
# Fix in the Bootstrap 4 version
# Re-test
# Document the fix
```

#### Option 2: Temporary Revert

```bash
# Revert just the problematic component
git revert <commit-hash>

# Document why in doc/migration-notes/
# Create issue to track
# Come back to it later
```

#### Option 3: Full Rollback

```bash
# Switch back to Bootstrap 3

# 1. Edit Gemfile:
# - Uncomment: gem 'bootstrap-sass', '~> 3.4.1'
# - Comment out: gem 'bootstrap', '~> 4.6.2'
bundle install

# 2. Edit mushroom_observer_migration.scss:
# - Uncomment Bootstrap 3 imports
# - Comment out Bootstrap 4 imports

# 3. Recompile
bundle exec rails assets:precompile

# 4. Deploy
```

### Emergency Production Rollback

If Bootstrap 4 is deployed and causes critical issues:

```bash
# 1. Immediate revert
git revert <migration-commit>
git push origin main

# 2. Or use feature flag (if implemented)
# In Rails console:
FeatureFlag.disable(:bootstrap_4)

# 3. Recompile and deploy
bundle exec rails assets:precompile RAILS_ENV=production
# Deploy via your normal process
```

## Common Issues

### Issue: Styles Look Different

**Symptom:** Component renders but looks wrong

**Causes:**
- Missing or renamed classes
- Different default styling in BS4
- Theme variable not mapped correctly

**Solutions:**
1. Check BS4 documentation for class name changes
2. Add compatibility shim in mushroom_observer_migration.scss
3. Verify theme variable mapping in mo/_map_theme_to_bootstrap4.scss
4. Check for conflicting custom CSS

### Issue: JavaScript Not Working

**Symptom:** Interactive components don't respond

**Causes:**
- Data attributes renamed
- Event names changed
- JavaScript API changed

**Solutions:**
1. Update data attributes (data-toggle, data-target, etc.)
2. Check Bootstrap 4 JavaScript documentation
3. Update event listeners if using BS JavaScript events
4. Verify jQuery version compatibility

### Issue: Responsive Breakpoints Wrong

**Symptom:** Mobile layout broken or different

**Causes:**
- BS4 changed breakpoint values
- `.col-xs-*` removed
- `.hidden-*` classes removed

**Solutions:**
1. Replace `.col-xs-*` with `.col-*`
2. Replace `.hidden-*` with display utilities (`.d-none`, `.d-md-block`)
3. Test at all breakpoints: XS, SM, MD, LG, XL

### Issue: Grid Layout Broken

**Symptom:** Columns not aligning or wrapping incorrectly

**Causes:**
- Flexbox grid in BS4 vs float grid in BS3
- Different gutters
- Changed offset classes

**Solutions:**
1. Remove clearfix hacks (not needed with flexbox)
2. Use BS4 flex utilities for alignment
3. Update offset classes (`.col-md-offset-*` → `.offset-md-*`)

### Issue: Form Validation Styling Missing

**Symptom:** Error states not showing

**Causes:**
- `.has-error` removed
- Validation classes changed

**Solutions:**
1. Add `.is-invalid` class to inputs
2. Use `.invalid-feedback` for error messages
3. Update form helper methods to generate correct classes

## Resources

### Documentation

- [Bootstrap 4 Migration Guide (Official)](https://getbootstrap.com/docs/4.6/migration/)
- [Bootstrap 4 Documentation](https://getbootstrap.com/docs/4.6/)
- [MO Theme System Analysis](./MO%20Theme%20System%20Analysis.md)
- [Bootstrap 4 Theme Mapping](./BOOTSTRAP4_THEME_MAPPING.md)

### Internal References

- Theme validation script: `script/validate_themes.rb`
- Theme variables: `app/assets/stylesheets/variables/`
- Migration stylesheet: `app/assets/stylesheets/mushroom_observer_migration.scss`
- BS3 mapping: `app/assets/stylesheets/mo/_map_theme_vars_to_bootstrap_vars.scss`
- BS4 mapping: `app/assets/stylesheets/mo/_map_theme_to_bootstrap4.scss`

### Tools

- [Bootstrap 3 to 4 Upgrade Tool](https://github.com/twbs/bootstrap/tree/main/build/migration)
- Screenshot comparison tools: ImageMagick, PixelMatch
- Browser DevTools for responsive testing
- Lighthouse for accessibility audits

### Getting Help

- Check Bootstrap 4 docs first
- Search closed Bootstrap GitHub issues
- Review MO migration notes in `doc/migration-notes/`
- Ask team members who've migrated components
- Document solutions for others

## Success Criteria

Before declaring migration complete:

- [ ] All components render correctly in BS4
- [ ] All 8 themes work with BS4
- [ ] All automated tests pass
- [ ] Visual regression tests pass
- [ ] Mobile/responsive layouts work
- [ ] JavaScript interactions work
- [ ] Performance is acceptable
- [ ] Accessibility maintained
- [ ] Cross-browser testing complete
- [ ] Documentation updated
- [ ] Bootstrap 3 gem removed
- [ ] No console errors or warnings

## Timeline

Estimated total time: **12 weeks** (3 months)

This assumes:
- 1 developer working part-time (50%)
- Testing with each component
- Buffer for unexpected issues

Can be accelerated with:
- Multiple developers in parallel
- Focus on critical components first
- Skip low-priority components initially

## Questions?

Contact: Nathan Wilson (@mo-nathan)
