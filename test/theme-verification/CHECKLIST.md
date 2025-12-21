# Theme System Verification Checklist

## Manual Visual Verification

For EACH theme (agaricus, amanita, cantharellaceae, hygrocybe, admin, sudo, black_on_white):

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
