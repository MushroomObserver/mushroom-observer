# Bootstrap 4 Breaking Changes Reference

## Overview

This document catalogs all breaking changes between Bootstrap 3 and Bootstrap 4 that affect Mushroom Observer. Use this as a quick reference when migrating components.

## Table of Contents

1. [Global Changes](#global-changes)
2. [Grid System](#grid-system)
3. [Typography](#typography)
4. [Forms](#forms)
5. [Buttons](#buttons)
6. [Navigation](#navigation)
7. [Cards (Panels)](#cards-panels)
8. [Tables](#tables)
9. [Utilities](#utilities)
10. [JavaScript Components](#javascript-components)

---

## Global Changes

### Flexbox by Default

**Bootstrap 3:** Float-based layout
**Bootstrap 4:** Flexbox-based layout

**Impact:** HIGH
- Grid behavior slightly different
- Vertical alignment easier
- Some clearfix hacks no longer needed
- Better responsive behavior

**Migration:** Remove clearfix usage where possible, test layouts carefully

### REM Units

**Bootstrap 3:** Pixels for most sizing
**Bootstrap 4:** REMs for typography and spacing

**Impact:** MEDIUM
- Sizes scale with root font size
- Better accessibility
- Calculations may differ slightly

**Migration:** No code changes needed, but verify visual sizes

### Dropped IE9 and iOS 6 Support

**Bootstrap 3:** IE8+ support
**Bootstrap 4:** IE10+ support

**Impact:** LOW (for MO)
- Cleaner code without IE9 hacks
- Modern CSS features available

**Migration:** Remove IE9-specific workarounds if any exist

---

## Grid System

### Extra Small Breakpoint Renamed

```scss
// Bootstrap 3
.col-xs-6  // 0px and up
.col-sm-6  // 768px and up
.col-md-6  // 992px and up
.col-lg-6  // 1200px and up

// Bootstrap 4
.col-6     // 0px and up (xs removed from name)
.col-sm-6  // 576px and up
.col-md-6  // 768px and up
.col-lg-6  // 992px and up
.col-xl-6  // 1200px and up (NEW)
```

**Impact:** HIGH
- All `.col-xs-*` must be renamed to `.col-*`
- New XL breakpoint available
- SM breakpoint changed from 768px to 576px

**Migration:**
```bash
# Find all usage
grep -r "col-xs-" app/views/

# Replace
.col-xs-6  →  .col-6
.col-xs-12 →  .col-12
```

### Offset Classes Renamed

```html
<!-- Bootstrap 3 -->
<div class="col-md-6 col-md-offset-3">

<!-- Bootstrap 4 -->
<div class="col-md-6 offset-md-3">
```

**Impact:** MEDIUM

**Migration:**
```bash
# Find usage
grep -r "col-.*-offset-" app/views/

# Replace
col-md-offset-3  →  offset-md-3
col-lg-offset-2  →  offset-lg-2
```

### Push/Pull Classes Renamed

```html
<!-- Bootstrap 3 -->
<div class="col-md-6 col-md-push-6">
<div class="col-md-6 col-md-pull-6">

<!-- Bootstrap 4 -->
<div class="col-md-6 order-md-2">
<div class="col-md-6 order-md-1">
```

**Impact:** LOW (if used)

**Migration:** Use flexbox ordering instead of push/pull

---

## Typography

### Display Headings

**Bootstrap 3:** Not available
**Bootstrap 4:** `.display-1` through `.display-4`

**Impact:** LOW (optional enhancement)

**Migration:** Can use for hero sections and large headings

### Small Text

```html
<!-- Bootstrap 3 -->
<small>Text</small>

<!-- Bootstrap 4 -->
<small class="text-muted">Text</small> or
<small class="text-secondary">Text</small>
```

**Impact:** LOW

**Migration:** Add color classes to `<small>` tags if needed

---

## Forms

### Form Control Static Renamed

```html
<!-- Bootstrap 3 -->
<p class="form-control-static">Read-only text</p>

<!-- Bootstrap 4 -->
<p class="form-control-plaintext">Read-only text</p>
```

**Impact:** MEDIUM

**Migration:**
```bash
grep -r "form-control-static" app/views/
# Replace with form-control-plaintext
```

### Help Block Renamed

```html
<!-- Bootstrap 3 -->
<span class="help-block">Help text</span>

<!-- Bootstrap 4 -->
<small class="form-text text-muted">Help text</small>
```

**Impact:** HIGH (commonly used)

**Migration:**
```bash
grep -r "help-block" app/views/
# Replace structure with small.form-text.text-muted
```

### Validation Classes Changed

```html
<!-- Bootstrap 3 -->
<div class="form-group has-error">
  <input class="form-control">
  <span class="help-block">Error message</span>
</div>

<!-- Bootstrap 4 -->
<div class="form-group">
  <input class="form-control is-invalid">
  <div class="invalid-feedback">Error message</div>
</div>
```

**Impact:** HIGH (affects all forms)

**Migration:**
- Remove `.has-error`, `.has-warning`, `.has-success` from form-group
- Add `.is-invalid` or `.is-valid` to inputs
- Change `.help-block` to `.invalid-feedback` or `.valid-feedback`
- Update form helpers to generate correct classes

### Horizontal Form Structure

```html
<!-- Bootstrap 3 -->
<form class="form-horizontal">
  <div class="form-group">
    <label class="col-sm-2 control-label">Label</label>
    <div class="col-sm-10">
      <input class="form-control">
    </div>
  </div>
</form>

<!-- Bootstrap 4 -->
<form>
  <div class="form-group row">
    <label class="col-sm-2 col-form-label">Label</label>
    <div class="col-sm-10">
      <input class="form-control">
    </div>
  </div>
</form>
```

**Impact:** HIGH

**Migration:**
- Remove `.form-horizontal` from form
- Add `.row` to `.form-group`
- Change `.control-label` to `.col-form-label`

### Input Sizing

```html
<!-- Bootstrap 3 -->
<input class="form-control input-lg">
<input class="form-control input-sm">

<!-- Bootstrap 4 -->
<input class="form-control form-control-lg">
<input class="form-control form-control-sm">
```

**Impact:** MEDIUM

**Migration:**
```bash
grep -r "input-lg\|input-sm" app/views/
# Replace
input-lg  →  form-control-lg
input-sm  →  form-control-sm
```

---

## Buttons

### Default Button Class Renamed

```html
<!-- Bootstrap 3 -->
<button class="btn btn-default">Button</button>

<!-- Bootstrap 4 -->
<button class="btn btn-secondary">Button</button>
```

**Impact:** HIGH (very common)

**Migration:**
```bash
grep -r "btn-default" app/views/
# Replace with btn-secondary
```

### Outline Buttons

**Bootstrap 3:** Not available (custom implementation)
**Bootstrap 4:** Built-in `.btn-outline-*` classes

**Impact:** LOW (optional)

**Migration:** Can replace custom outline buttons with BS4 classes

### Button Sizing

```html
<!-- Bootstrap 3 -->
<button class="btn btn-xs">Tiny</button>

<!-- Bootstrap 4 -->
<button class="btn btn-sm">Small</button>
<!-- .btn-xs removed, use .btn-sm -->
```

**Impact:** MEDIUM

**Migration:**
```bash
grep -r "btn-xs" app/views/
# Replace with btn-sm or use custom CSS
```

---

## Navigation

### Navbar Structure Changed

```html
<!-- Bootstrap 3 -->
<nav class="navbar navbar-default">
  <div class="navbar-header">
    <button class="navbar-toggle">
      <span class="icon-bar"></span>
    </button>
    <a class="navbar-brand">Brand</a>
  </div>
  <div class="collapse navbar-collapse">
    <ul class="nav navbar-nav">
      <li><a href="#">Link</a></li>
    </ul>
  </div>
</nav>

<!-- Bootstrap 4 -->
<nav class="navbar navbar-expand-lg navbar-light">
  <a class="navbar-brand">Brand</a>
  <button class="navbar-toggler">
    <span class="navbar-toggler-icon"></span>
  </button>
  <div class="collapse navbar-collapse">
    <ul class="navbar-nav">
      <li class="nav-item">
        <a class="nav-link" href="#">Link</a>
      </li>
    </ul>
  </div>
</nav>
```

**Impact:** VERY HIGH (major restructure)

**Changes:**
- `.navbar-default` → `.navbar-light` + `.navbar-expand-*`
- `.navbar-inverse` → `.navbar-dark`
- `.navbar-toggle` → `.navbar-toggler`
- `.icon-bar` → `.navbar-toggler-icon`
- `.nav.navbar-nav` → `.navbar-nav`
- Add `.nav-item` to `<li>`
- Add `.nav-link` to `<a>`
- `.navbar-header` removed
- `.navbar-right` → `.ml-auto`
- `.navbar-left` → `.mr-auto`

**Migration:** Plan substantial time for navbar updates

### Nav Stacked Removed

```html
<!-- Bootstrap 3 -->
<ul class="nav nav-pills nav-stacked">

<!-- Bootstrap 4 -->
<ul class="nav flex-column">
<!-- or -->
<div class="nav flex-column nav-pills">
```

**Impact:** MEDIUM

**Migration:** Replace `.nav-stacked` with `.flex-column`

---

## Cards (Panels)

### Panels Replaced with Cards

```html
<!-- Bootstrap 3 -->
<div class="panel panel-default">
  <div class="panel-heading">
    <h3 class="panel-title">Title</h3>
  </div>
  <div class="panel-body">
    Content
  </div>
  <div class="panel-footer">
    Footer
  </div>
</div>

<!-- Bootstrap 4 -->
<div class="card">
  <div class="card-header">
    <h3 class="card-title">Title</h3>
  </div>
  <div class="card-body">
    Content
  </div>
  <div class="card-footer">
    Footer
  </div>
</div>
```

**Impact:** VERY HIGH (panels used extensively)

**Changes:**
- `.panel` → `.card`
- `.panel-heading` → `.card-header`
- `.panel-title` → `.card-title`
- `.panel-body` → `.card-body`
- `.panel-footer` → `.card-footer`
- `.panel-default`, `.panel-primary` → Use `.bg-*` utilities on card

**Migration:**
```bash
grep -r "panel panel-" app/views/
# Systematic replacement needed
```

### Thumbnails Removed

**Bootstrap 3:** `.thumbnail` class
**Bootstrap 4:** Use `.card` instead

**Impact:** MEDIUM

**Migration:** Replace thumbnails with cards containing images

---

## Tables

### Table Condensed Renamed

```html
<!-- Bootstrap 3 -->
<table class="table table-condensed">

<!-- Bootstrap 4 -->
<table class="table table-sm">
```

**Impact:** MEDIUM

**Migration:**
```bash
grep -r "table-condensed" app/views/
# Replace with table-sm
```

### Contextual Classes

```html
<!-- Bootstrap 3 -->
<tr class="active">
<tr class="success">
<tr class="warning">
<tr class="danger">
<tr class="info">

<!-- Bootstrap 4 -->
<tr class="table-active">
<tr class="table-success">
<tr class="table-warning">
<tr class="table-danger">
<tr class="table-info">
```

**Impact:** MEDIUM

**Migration:** Add `table-` prefix to contextual classes

---

## Utilities

### Visibility Classes Changed

```html
<!-- Bootstrap 3 -->
<div class="hidden-xs">Hidden on extra small</div>
<div class="visible-md">Visible on medium</div>

<!-- Bootstrap 4 -->
<div class="d-none d-sm-block">Hidden on extra small</div>
<div class="d-none d-md-block">Visible on medium</div>
```

**Impact:** HIGH

**Changes:**
- `.hidden-*` removed
- `.visible-*` removed
- Use display utilities: `.d-none`, `.d-block`, `.d-{breakpoint}-{value}`

**Migration:**
```bash
grep -r "hidden-\|visible-" app/views/
# Replace with display utilities
```

### Text Alignment Responsive

```html
<!-- Bootstrap 3 -->
<div class="text-center">Centered</div>

<!-- Bootstrap 4 -->
<div class="text-center">Centered</div>
<!-- Same, but now responsive variants available -->
<div class="text-sm-left text-md-center">Responsive alignment</div>
```

**Impact:** LOW (enhancement)

**Migration:** Optional - can add responsive text alignment

### Floats

```html
<!-- Bootstrap 3 -->
<div class="pull-left">Left</div>
<div class="pull-right">Right</div>

<!-- Bootstrap 4 -->
<div class="float-left">Left</div>
<div class="float-right">Right</div>
```

**Impact:** MEDIUM

**Migration:**
```bash
grep -r "pull-left\|pull-right" app/views/
# Replace
pull-left   →  float-left
pull-right  →  float-right
```

### Labels Renamed to Badges

```html
<!-- Bootstrap 3 -->
<span class="label label-default">Label</span>
<span class="label label-primary">Label</span>

<!-- Bootstrap 4 -->
<span class="badge badge-secondary">Badge</span>
<span class="badge badge-primary">Badge</span>
```

**Impact:** MEDIUM

**Changes:**
- `.label` → `.badge`
- `.label-default` → `.badge-secondary`
- Pill style: `.label-pill` → `.badge-pill`

**Migration:**
```bash
grep -r "\\blabel\\b" app/views/  # \b for word boundary
# Replace label with badge
```

### Wells Removed

```html
<!-- Bootstrap 3 -->
<div class="well">Content</div>
<div class="well well-sm">Small well</div>

<!-- Bootstrap 4 -->
<div class="card bg-light">
  <div class="card-body">Content</div>
</div>
```

**Impact:** MEDIUM

**Migration:** Replace wells with cards using `.bg-light` utility

---

## JavaScript Components

### Data Attributes Standardized

**Bootstrap 3:** Inconsistent naming
**Bootstrap 4:** Consistent `data-` attributes

**Impact:** MEDIUM

**Migration:** Update data attributes:
- `data-toggle`
- `data-target`
- `data-dismiss`
- etc.

### Modal Changes

```html
<!-- Bootstrap 3 -->
<div class="modal">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <button class="close" data-dismiss="modal">&times;</button>
        <h4 class="modal-title">Title</h4>
      </div>
    </div>
  </div>
</div>

<!-- Bootstrap 4 -->
<div class="modal">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Title</h5>
        <button class="close" data-dismiss="modal">&times;</button>
      </div>
    </div>
  </div>
</div>
```

**Impact:** MEDIUM

**Changes:**
- Title and close button order switched
- `.modal-title` changed from `<h4>` to `<h5>`
- Centering uses `.modal-dialog-centered`

### Dropdown Changes

**Impact:** MEDIUM

**Changes:**
- `.dropdown-toggle` caret is now optional
- Alignment classes: `.dropdown-menu-right` → `.dropdown-menu-end`
- Divider: `.divider` → `.dropdown-divider`
- Header: `.dropdown-header` (same but applied to `<h6>`)

### Carousel Indicators

```html
<!-- Bootstrap 3 -->
<ol class="carousel-indicators">
  <li data-target="#carousel" data-slide-to="0" class="active"></li>
</ol>

<!-- Bootstrap 4 -->
<div class="carousel-indicators">
  <button data-bs-target="#carousel" data-bs-slide-to="0" class="active"></button>
</div>
```

**Impact:** LOW (if using carousels)

**Changes:**
- `<ol>` → `<div>`
- `<li>` → `<button>`
- `data-target` → `data-bs-target`
- `data-slide-to` → `data-bs-slide-to`

---

## Summary Checklist

Use this checklist when reviewing code:

### Must Change
- [ ] `.col-xs-*` → `.col-*`
- [ ] `.col-*-offset-*` → `.offset-*-*`
- [ ] `.btn-default` → `.btn-secondary`
- [ ] `.panel*` → `.card*`
- [ ] `.label` → `.badge`
- [ ] `.form-control-static` → `.form-control-plaintext`
- [ ] `.help-block` → `.form-text`
- [ ] `.has-error` → `.is-invalid`
- [ ] `.pull-left` → `.float-left`
- [ ] `.pull-right` → `.float-right`
- [ ] `.hidden-*` → `.d-none .d-*-block`
- [ ] `.navbar-default` → `.navbar-light`
- [ ] `.navbar-toggle` → `.navbar-toggler`
- [ ] `.table-condensed` → `.table-sm`

### Check If Used
- [ ] `.well` → cards with `.bg-light`
- [ ] `.thumbnail` → `.card` with images
- [ ] `.nav-stacked` → `.flex-column`
- [ ] `.input-lg/sm` → `.form-control-lg/sm`
- [ ] `.btn-xs` → `.btn-sm` or custom
- [ ] Form validation structure
- [ ] Navbar structure
- [ ] Modal structure
- [ ] Dropdown structure

---

## Resources

- [Official Bootstrap 4 Migration Guide](https://getbootstrap.com/docs/4.6/migration/)
- [Bootstrap 4 Documentation](https://getbootstrap.com/docs/4.6/)
- [MO Migration Guide](./BOOTSTRAP_MIGRATION_GUIDE.md)
