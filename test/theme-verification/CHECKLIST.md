# Theme System Verification Checklist

Run this checklist AFTER completing Phase 1 changes.

## Automated Checks

- [ ] Run: `script/verify_theme_changes.rb extract after`
- [ ] Run: `rails assets:precompile RAILS_ENV=production`
- [ ] Check: No new compilation errors or warnings

## Manual Visual Verification

For EACH theme (agaricus, amanita, cantharellaceae, hygrocybe, admin, sudo, black_on_white, defaults):

### Homepage (/)
- [ ] Menu colors are correct
- [ ] Link colors are correct
- [ ] Background colors are correct

### Observation Index (/observations)
- [ ] Pager colors are correct
- [ ] Search form renders correctly
- [ ] Result cards render correctly

### Observation Show (/observations/:id)
- [ ] Vote meter colors are correct
- [ ] Button colors are correct
- [ ] Tooltips appear correctly
- [ ] Image thumbnails render correctly

### Forms (/observations/new or /account/login)
- [ ] Input field colors are correct
- [ ] Button hover states work
- [ ] Error messages display correctly
- [ ] Help text is readable

### User Profile (/users/:id)
- [ ] Profile card colors are correct
- [ ] Progress bars (if any) render correctly
- [ ] Wells/panels render correctly

## Comparison with Baseline

- [ ] Compare screenshots side-by-side
- [ ] Check for any color shifts
- [ ] Verify no layout changes
- [ ] Check that hover/active states still work

## Variable Comparison

- [ ] Run: `diff -r test/theme-verification/baseline test/theme-verification/after`
- [ ] Review any differences - should only be ADDITIONS to defaults
- [ ] Verify individual themes have NOT changed

## Sign-off

- [ ] All visual checks passed
- [ ] No compilation errors
- [ ] Variable changes are as expected
- [ ] Ready for Phase 2

Verified by: __________________  Date: __________
