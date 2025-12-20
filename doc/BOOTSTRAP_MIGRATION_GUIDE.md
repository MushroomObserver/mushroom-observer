# Bootstrap 3 to 4 Migration Guide

## Overview

This guide covers the migration from Bootstrap 3 to Bootstrap 4 for Mushroom Observer. The migration uses a **parallel systems approach** that allows both Bootstrap versions to coexist during the transition period.

## Table of Contents

1. [Migration Strategy](#migration-strategy)
2. [Setup Instructions](#setup-instructions)
3. [Component Migration Order](#component-migration-order)
4. [Testing Methodology](#testing-methodology)
5. [Rollback Procedures](#rollback-procedures)
6. [Common Issues](#common-issues)
7. [Resources](#resources)

## Migration Strategy

### Parallel Systems Approach

Instead of a "big bang" migration, we use a **gradual, component-by-component** approach:

1. **Bootstrap 3 remains the default** until all components are migrated and tested
2. **Bootstrap 4 can be enabled** for development/testing via configuration flag
3. **Components are migrated incrementally** with testing after each change
4. **Theme system remains unchanged** - both Bootstrap versions use the same theme variables
5. **Final switchover** happens only after all components pass testing

### Benefits

- ✅ Lower risk - can revert individual components if issues arise
- ✅ Incremental progress - don't need to fix everything at once
- ✅ Continuous testing - catch issues early component-by-component
- ✅ Minimal disruption - production stays on BS3 until ready
- ✅ Theme compatibility - themes work with both versions

## Setup Instructions

### 1. Install Bootstrap 4 Gem

Add to `Gemfile` after line for `bootstrap-sass`:

```ruby
# Bootstrap 4 (migration target)
gem("bootstrap", "~> 4.6.2")
```

Run:
```bash
bundle install
```

### 2. Confirm Bootstrap Version Configuration

Look at `app/assets/stylesheets/mo/_bootstrap_config.scss` and confirm that it contains these lines:

```scss
// Set to true to use Bootstrap 3 (current production version)                                                               
$use-bootstrap-3: true !default;

// Set to true to use Bootstrap 4 (migration target)                                                                         
$use-bootstrap-4: false !default;
```

### 3. Switch to Migration-Ready Stylesheet (Optional for Testing)

To test the parallel system:

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

1. Set `$use-bootstrap-4: true` in `mo/_bootstrap_config.scss`
2. Comment out the temporary error in `mushroom_observer_migration.scss`
3. Uncomment the Bootstrap 4 import line
4. Recompile assets
5. Test in browser

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
# Set $use-bootstrap-3: true in mo/_bootstrap_config.scss

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
# Set $use-bootstrap-4: true in mo/_bootstrap_config.scss

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

For critical components, set up side-by-side comparison:

1. Run two local servers:
```bash
# Terminal 1: Bootstrap 3
$use-bootstrap-3: true
bundle exec rails server -p 3000

# Terminal 2: Bootstrap 4
$use-bootstrap-4: true
bundle exec rails server -p 3001
```

2. Open both in browser windows side-by-side
3. Navigate through same pages simultaneously
4. Document any differences

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
# Edit mo/_bootstrap_config.scss
$use-bootstrap-3: true
$use-bootstrap-4: false

# Recompile
bundle exec rails assets:precompile

# Deploy
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
- Bootstrap config: `app/assets/stylesheets/mo/_bootstrap_config.scss`
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
