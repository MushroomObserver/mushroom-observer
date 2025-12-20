# Bootstrap 4 Migration Checklist

## Pre-Migration Setup

- [ ] Bootstrap 4 gem installed (`gem 'bootstrap', '~> 4.6.2'`)
- [ ] Theme system standardization complete (Phases 1-5)
- [ ] Bootstrap config file created (`mo/_bootstrap_config.scss`)
- [ ] Bootstrap 4 mapping created (`mo/_map_theme_to_bootstrap4.scss`)
- [ ] Migration documentation reviewed
- [ ] Feature branch created (`git checkout -b bootstrap4-migration`)

## Phase 1: Foundation Components

### Typography
- [ ] Body text renders correctly
- [ ] Headings (h1-h6) styled properly
- [ ] Paragraph spacing correct
- [ ] Text utilities work (.text-muted, .text-primary, etc.)
- [ ] Lead paragraphs styled
- [ ] Small text styled
- [ ] All themes tested
- [ ] Screenshots captured and compared

### Colors & Backgrounds
- [ ] Contextual colors work (.text-success, .text-danger, etc.)
- [ ] Background utilities work (.bg-primary, .bg-light, etc.)
- [ ] All 8 semantic colors rendering correctly
- [ ] Theme-specific colors applied
- [ ] All themes tested

### Spacing Utilities
- [ ] Margin utilities work (.m-*, .mt-*, .mx-*, etc.)
- [ ] Padding utilities work (.p-*, .pt-*, .px-*, etc.)
- [ ] Spacing scale consistent with design
- [ ] Responsive spacing variants tested

## Phase 2: Forms

### Basic Form Controls
- [ ] Text inputs styled correctly
- [ ] Textareas styled correctly
- [ ] Select dropdowns styled
- [ ] File inputs styled
- [ ] Placeholder text colored correctly
- [ ] Disabled states work
- [ ] Focus states styled
- [ ] All themes tested

### Checkboxes and Radios
- [ ] Standard checkboxes work
- [ ] Standard radios work
- [ ] Inline checkboxes work
- [ ] Inline radios work
- [ ] Custom checkboxes/radios if needed
- [ ] Disabled states work

### Form Validation
- [ ] Error states display correctly (.is-invalid)
- [ ] Success states display correctly (.is-valid)
- [ ] Error messages styled (.invalid-feedback)
- [ ] Success messages styled (.valid-feedback)
- [ ] Form helpers generate correct classes
- [ ] Server-side validation displays errors
- [ ] Client-side validation works

### Form Layouts
- [ ] Vertical forms work
- [ ] Horizontal forms work (.form-group.row)
- [ ] Inline forms work
- [ ] Form groups spaced correctly
- [ ] Labels aligned properly
- [ ] Help text positioned correctly (.form-text)

### Input Groups
- [ ] Input groups render
- [ ] Prepended text works
- [ ] Appended text works
- [ ] Buttons in input groups work
- [ ] Dropdowns in input groups work
- [ ] Sizing works (.input-group-sm, .input-group-lg)

### Complex Forms Tested
- [ ] Observation creation form
- [ ] Name creation form
- [ ] User registration form
- [ ] Login form
- [ ] Account settings form
- [ ] Search forms
- [ ] Filter forms

## Phase 3: Buttons

### Button Variants
- [ ] Primary buttons (.btn-primary)
- [ ] Secondary buttons (.btn-secondary) - was .btn-default
- [ ] Success buttons (.btn-success)
- [ ] Danger buttons (.btn-danger)
- [ ] Warning buttons (.btn-warning)
- [ ] Info buttons (.btn-info)
- [ ] Light buttons (.btn-light)
- [ ] Dark buttons (.btn-dark)
- [ ] Link buttons (.btn-link)
- [ ] Outline variants (.btn-outline-*)

### Button Sizes
- [ ] Large buttons (.btn-lg)
- [ ] Default size buttons
- [ ] Small buttons (.btn-sm)
- [ ] Block buttons (.btn-block)
- [ ] All sizes tested with all variants

### Button States
- [ ] Active state styled
- [ ] Disabled state styled
- [ ] Hover states work
- [ ] Focus states work (keyboard navigation)
- [ ] Loading/processing state if custom

### Button Groups
- [ ] Horizontal button groups work
- [ ] Vertical button groups work (.btn-group-vertical)
- [ ] Button toolbar works if used
- [ ] Sizing works (.btn-group-sm, .btn-group-lg)

### Dropdown Buttons
- [ ] Basic dropdown button works
- [ ] Split dropdown works
- [ ] Dropdown menu styled
- [ ] Dropdown items clickable
- [ ] Dropdown dividers work
- [ ] Dropdown headers work
- [ ] Right-aligned dropdowns work

## Phase 4: Navigation

### Top Navbar
- [ ] Navbar structure updated
- [ ] Light navbar variant (.navbar-light)
- [ ] Brand/logo displays
- [ ] Navigation links work
- [ ] Responsive collapse works
- [ ] Toggler button works (.navbar-toggler)
- [ ] Search form in navbar works
- [ ] Dropdowns in navbar work
- [ ] User menu dropdown works
- [ ] Login button styled
- [ ] Mobile view tested
- [ ] All themes tested

### Left Sidebar Navigation
- [ ] Sidebar renders
- [ ] Navigation items styled
- [ ] Active states work
- [ ] Hover states work
- [ ] Icons if used
- [ ] Collapsible sections if used
- [ ] Mobile behavior correct
- [ ] All themes tested

### Breadcrumbs
- [ ] Breadcrumbs render
- [ ] Separators correct
- [ ] Active item styled
- [ ] Links work
- [ ] Responsive behavior

### Tabs
- [ ] Tab navigation renders
- [ ] Tab panes show/hide
- [ ] Active tab highlighted
- [ ] JavaScript switching works
- [ ] Responsive behavior
- [ ] Pills variant if used

### Pagination (covered in Phase 6)

## Phase 5: Layout Components

### Cards (formerly Panels)
- [ ] Basic cards render (.card)
- [ ] Card headers work (.card-header)
- [ ] Card bodies work (.card-body)
- [ ] Card footers work (.card-footer)
- [ ] Card titles styled (.card-title)
- [ ] Card text styled (.card-text)
- [ ] Card images work
- [ ] Card links styled
- [ ] Colored cards work (.bg-primary, etc.)
- [ ] Card groups if used
- [ ] Card decks if used
- [ ] All card usage migrated from panels
- [ ] All themes tested

### List Groups
- [ ] Basic list groups render
- [ ] Active items styled
- [ ] Disabled items styled
- [ ] Actionable list groups (links/buttons)
- [ ] Flush list groups if used
- [ ] Contextual classes work
- [ ] Badges in list groups
- [ ] Custom content in list groups

### Media Objects
- [ ] Media objects render
- [ ] Images aligned (left/right)
- [ ] Nested media objects work
- [ ] Responsive behavior

### Responsive Utilities
- [ ] Display utilities work (.d-none, .d-block, etc.)
- [ ] Responsive display utilities work (.d-md-block, etc.)
- [ ] Float utilities work (.float-left, .float-right)
- [ ] Responsive floats work (.float-md-left, etc.)
- [ ] Text alignment utilities work
- [ ] Responsive text alignment works

## Phase 6: Content Display

### Tables
- [ ] Basic tables styled (.table)
- [ ] Striped rows work (.table-striped)
- [ ] Bordered tables work (.table-bordered)
- [ ] Borderless tables work (.table-borderless)
- [ ] Hover rows work (.table-hover)
- [ ] Small tables work (.table-sm) - was .table-condensed
- [ ] Responsive tables work (.table-responsive)
- [ ] Contextual row classes work (.table-success, etc.)
- [ ] Dark tables if used (.table-dark)
- [ ] Table headers styled
- [ ] Table captions if used
- [ ] All data tables tested
- [ ] All themes tested

### Pagination
- [ ] Basic pagination renders
- [ ] Page numbers styled
- [ ] Active page highlighted
- [ ] Disabled pages styled
- [ ] Previous/next links work
- [ ] First/last links if used
- [ ] Alignment works (.justify-content-*)
- [ ] Sizing works (.pagination-sm, .pagination-lg)
- [ ] Theme colors applied correctly
- [ ] All pagination tested (observations, names, images, etc.)

### Badges (formerly Labels)
- [ ] Basic badges render (.badge)
- [ ] Badge variants work (.badge-primary, etc.)
- [ ] Pill badges work (.badge-pill)
- [ ] Badges in headings
- [ ] Badges in buttons
- [ ] Badges in nav items
- [ ] Counter badges
- [ ] All themes tested

### Alerts
- [ ] Alert variants work (.alert-success, .alert-danger, etc.)
- [ ] Dismissible alerts work
- [ ] Close button styled
- [ ] Alert links styled (.alert-link)
- [ ] Icons in alerts if used
- [ ] Theme colors applied
- [ ] Flash messages work
- [ ] Validation errors display
- [ ] Success messages display
- [ ] All themes tested

### Progress Bars
- [ ] Basic progress bar renders
- [ ] Progress value displays
- [ ] Contextual variants work (.bg-success, etc.)
- [ ] Striped progress bars if used
- [ ] Animated stripes if used
- [ ] Multiple bars if used
- [ ] Labels if used
- [ ] Theme colors applied
- [ ] All uses tested

## Phase 7: Interactive Components

### Modals
- [ ] Basic modal renders
- [ ] Modal opens on trigger
- [ ] Modal closes on X button
- [ ] Modal closes on backdrop click
- [ ] Modal header styled
- [ ] Modal body styled
- [ ] Modal footer styled
- [ ] Close button positioned correctly
- [ ] Large modals work (.modal-lg)
- [ ] Small modals work (.modal-sm)
- [ ] Scrollable modals work
- [ ] Centered modals work (.modal-dialog-centered)
- [ ] Nested modals if used
- [ ] All modal uses tested
- [ ] JavaScript events work

### Dropdowns
- [ ] Basic dropdowns work
- [ ] Dropdown toggles styled
- [ ] Dropdown menus positioned
- [ ] Dropdown items styled
- [ ] Active items highlighted
- [ ] Disabled items styled
- [ ] Dropdown headers work
- [ ] Dropdown dividers work
- [ ] Right-aligned dropdowns work (.dropdown-menu-end)
- [ ] Dropup variant if used
- [ ] Dropdowns in navbars work
- [ ] All dropdown uses tested

### Tooltips
- [ ] Tooltips display on hover
- [ ] Tooltip content shows
- [ ] Tooltip positioning correct (top/right/bottom/left)
- [ ] Tooltips styled with theme colors
- [ ] Tooltips don't interfere with clicks
- [ ] Mobile behavior acceptable
- [ ] All tooltip uses tested

### Popovers
- [ ] Popovers display on click/hover
- [ ] Popover title shows
- [ ] Popover content shows
- [ ] Popover positioning correct
- [ ] Popover dismiss works
- [ ] Popovers styled
- [ ] All popover uses tested

### Collapse/Accordion
- [ ] Collapsible sections work
- [ ] Collapse toggle works
- [ ] Multiple collapse sections work
- [ ] Accordion behavior works (one open at a time)
- [ ] Initial state correct
- [ ] Transition smooth
- [ ] All collapse uses tested

## Phase 8: Grid System

### Container
- [ ] Fixed container works (.container)
- [ ] Fluid container works (.container-fluid)
- [ ] Responsive containers if used (.container-sm, etc.)
- [ ] Container padding correct

### Rows and Columns
- [ ] Basic 12-column grid works
- [ ] Column sizing correct (.col-6, .col-md-4, etc.)
- [ ] Extra small breakpoint works (.col-*)
- [ ] Small breakpoint works (.col-sm-*)
- [ ] Medium breakpoint works (.col-md-*)
- [ ] Large breakpoint works (.col-lg-*)
- [ ] Extra large breakpoint works (.col-xl-*) - NEW in BS4
- [ ] Auto-layout columns work (.col)
- [ ] Column wrapping works
- [ ] No gutters if used (.no-gutters)

### Offsets and Ordering
- [ ] Offsets work (.offset-md-3, etc.) - was .col-md-offset-3
- [ ] Column ordering works (.order-*) - was .col-*-push/pull
- [ ] First/last utilities work (.order-first, .order-last)
- [ ] Responsive ordering works

### Alignment
- [ ] Vertical alignment works (.align-items-*, .align-self-*)
- [ ] Horizontal alignment works (.justify-content-*)
- [ ] Responsive alignment works

### All Layouts Tested
- [ ] Homepage layout
- [ ] Observation show page layout
- [ ] Observation index layout
- [ ] Name show page layout
- [ ] Search results layout
- [ ] User profile layout
- [ ] Forms layouts
- [ ] Mobile layouts
- [ ] Tablet layouts

## Phase 9: Specialized Components

### Carousels
- [ ] Carousel renders
- [ ] Slides transition
- [ ] Controls work (prev/next)
- [ ] Indicators work
- [ ] Auto-play works if enabled
- [ ] Captions display
- [ ] Images sized correctly
- [ ] Responsive behavior
- [ ] All carousel uses tested

### Jumbotrons
- [ ] Jumbotron renders
- [ ] Fluid variant works if used
- [ ] Content styled correctly
- [ ] Background works
- [ ] Responsive behavior
- [ ] All jumbotron uses tested

### Wells Replacement
- [ ] All .well uses identified
- [ ] Replaced with .card + .bg-light
- [ ] Content looks same/better
- [ ] All themes tested

### Custom MO Components
- [ ] Vote meters work
- [ ] Logo displays correctly
- [ ] Image galleries work
- [ ] Maps render
- [ ] Name lister works
- [ ] Matrix box works
- [ ] Autocomplete works
- [ ] Status lights work
- [ ] Icons display
- [ ] All custom components tested

## Phase 10: Testing & Cleanup

### Cross-Browser Testing
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)
- [ ] Mobile Safari (iOS)
- [ ] Mobile Chrome (Android)

### Responsive Testing
- [ ] Desktop (1920x1080)
- [ ] Laptop (1366x768)
- [ ] Tablet portrait (768x1024)
- [ ] Tablet landscape (1024x768)
- [ ] Mobile (375x667 - iPhone SE)
- [ ] Mobile (414x896 - iPhone XR)
- [ ] Large mobile (428x926 - iPhone Pro Max)

### Theme Testing
- [ ] Agaricus theme complete
- [ ] Amanita theme complete
- [ ] Cantharellaceae theme complete
- [ ] Hygrocybe theme complete
- [ ] Admin theme complete
- [ ] Sudo theme complete
- [ ] BlackOnWhite theme complete
- [ ] Defaults theme complete

### Automated Testing
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All system tests pass
- [ ] No console errors
- [ ] No console warnings
- [ ] Rubocop passes
- [ ] Theme validation passes

### Accessibility
- [ ] Keyboard navigation works
- [ ] Focus indicators visible
- [ ] Screen reader tested (basic)
- [ ] Color contrast meets WCAG AA
- [ ] Form labels associated
- [ ] ARIA attributes if needed

### Performance
- [ ] CSS file size acceptable
- [ ] Page load time acceptable
- [ ] No layout shifts (CLS)
- [ ] Lighthouse score acceptable
- [ ] Mobile performance acceptable

### Documentation
- [ ] Component migration notes written
- [ ] Breaking changes documented
- [ ] New patterns documented
- [ ] Developer notes updated
- [ ] User-facing changes noted

### Cleanup
- [ ] Bootstrap 3 compatibility shims removed
- [ ] Unused CSS removed
- [ ] Comments cleaned up
- [ ] TODO items resolved or tracked
- [ ] Code formatted consistently
- [ ] Unused variables removed

### Final Steps
- [ ] Bootstrap 3 gem removed from Gemfile
- [ ] Old mapping file removed (map_theme_vars_to_bootstrap_vars.scss)
- [ ] Migration stylesheet becomes main stylesheet
- [ ] Config file defaults to Bootstrap 4
- [ ] All branches merged
- [ ] Production deployment successful
- [ ] Monitoring for issues

## Sign-Off

- [ ] Lead developer approval
- [ ] Designer approval
- [ ] QA sign-off
- [ ] Stakeholder approval
- [ ] Production deployment complete

## Post-Migration

- [ ] Monitor error logs
- [ ] Monitor user feedback
- [ ] Track performance metrics
- [ ] Document lessons learned
- [ ] Update team documentation
- [ ] Archive migration artifacts

---

**Completed:** ____ / ____ items

**Estimated Completion:** ______

**Actual Completion:** ______

**Notes:**
