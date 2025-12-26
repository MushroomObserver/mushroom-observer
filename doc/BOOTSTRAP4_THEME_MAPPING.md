# Bootstrap 4 Theme Mapping Documentation

## Overview

This document describes how Mushroom Observer's standardized theme variables map to Bootstrap 4's variable system.

## File Location

`app/assets/stylesheets/mo/_map_theme_to_bootstrap4.scss`

## Purpose

The mapping file serves as a translation layer between:
- **MO Theme System**: Standardized theme variables (e.g., `$PRIMARY_COLOR`, `$BUTTON_FG_COLOR`)
- **Bootstrap 4**: Framework variables (e.g., `$primary`, `$btn-font-weight`)

This allows MO themes to control Bootstrap 4's appearance without modifying theme files when migrating from Bootstrap 3.

## Import Order

For the mapping to work correctly, imports must follow this order:

```scss
// In theme files (e.g., Agaricus.scss)
@import "variables/defaults";
@import "variables/agaricus";
@import "mo/map_theme_to_bootstrap4";  // Translation layer
@import "bootstrap";                    // Bootstrap 4 framework
@import "mo/elements";                  // MO custom styles
```

## Mapped Variables

### 1. Semantic Colors

MO's semantic color system maps directly to Bootstrap 4's core colors:

| MO Variable | Bootstrap 4 Variable | Usage |
|-------------|---------------------|-------|
| `$PRIMARY_COLOR` | `$primary` | Primary actions, links, active states |
| `$SECONDARY_COLOR` | `$secondary` | Secondary actions, muted elements |
| `$SUCCESS_COLOR` | `$success` | Success messages, confirmations |
| `$INFO_COLOR` | `$info` | Informational messages |
| `$WARNING_COLOR` | `$warning` | Warning messages, cautions |
| `$DANGER_COLOR` | `$danger` | Error messages, destructive actions |
| `$LIGHT_COLOR` | `$light` | Light backgrounds, dividers |
| `$DARK_COLOR` | `$dark` | Dark backgrounds, primary text |

These generate component variants automatically:
- Buttons: `.btn-primary`, `.btn-success`, etc.
- Alerts: `.alert-info`, `.alert-danger`, etc.
- Badges: `.badge-warning`, `.badge-secondary`, etc.

### 2. Typography

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$BODY_FG_COLOR` | `$body-color` |
| `$BODY_BG_COLOR` | `$body-bg` |
| `$LINK_FG_COLOR` | `$link-color` |
| `$LINK_HOVER_FG_COLOR` | `$link-hover-color` |

### 3. Buttons

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$BUTTON_BORDER_RADIUS` | `$btn-border-radius` |
| `$LINK_FG_COLOR` | `$btn-link-color` |
| `$LINK_HOVER_FG_COLOR` | `$btn-link-hover-color` |

**Note**: Button color variants (`.btn-primary`, `.btn-success`, etc.) are generated automatically from `$theme-colors` map.

### 4. Form Controls

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$INPUT_BG_COLOR` | `$input-bg` |
| `$INPUT_FG_COLOR` | `$input-color` |
| `$INPUT_BORDER_COLOR` | `$input-border-color` |
| `$INPUT_BORDER_WIDTH` | `$input-border-width` |
| `$INPUT_BORDER_RADIUS` | `$input-border-radius` |
| `$PRIMARY_COLOR` | `$input-focus-border-color` |

### 5. Dropdowns & Menus

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$MENU_BG_COLOR` | `$dropdown-bg` |
| `$MENU_BORDER_COLOR` | `$dropdown-border-color` |
| `$MENU_FG_COLOR` | `$dropdown-link-color` |
| `$MENU_HOT_FG_COLOR` | `$dropdown-link-hover-color` |
| `$MENU_HOT_BG_COLOR` | `$dropdown-link-hover-bg` |
| `$MENU_WARM_FG_COLOR` | `$dropdown-link-active-color` |
| `$MENU_WARM_BG_COLOR` | `$dropdown-link-active-bg` |

### 6. Navigation

| MO Variable | Bootstrap 4 Variable | Context |
|-------------|---------------------|---------|
| `$TOP_BAR_FG_COLOR` | `$navbar-light-color` | Light navbar |
| `$TOP_BAR_LINK_HOVER_FG_COLOR` | `$navbar-light-hover-color` | Light navbar hover |
| `$LEFT_BAR_FG_COLOR` | `$navbar-dark-color` | Dark navbar |
| `$LEFT_BAR_HOVER_FG_COLOR` | `$navbar-dark-hover-color` | Dark navbar hover |

### 7. Pagination

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$PAGER_FG_COLOR` | `$pagination-color` |
| `$PAGER_BG_COLOR` | `$pagination-bg` |
| `$PAGER_HOVER_FG_COLOR` | `$pagination-hover-color` |
| `$PAGER_HOVER_BG_COLOR` | `$pagination-hover-bg` |
| `$PAGER_ACTIVE_FG_COLOR` | `$pagination-active-color` |
| `$PAGER_ACTIVE_BG_COLOR` | `$pagination-active-bg` |

### 8. Tables

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$LIST_BG_COLOR` | `$table-bg` |
| `$LIST_ODD_BG_COLOR` | `$table-accent-bg` |
| `$LIST_HOVER_BG_COLOR` | `$table-hover-bg` |
| `$LIST_BORDER_COLOR` | `$table-border-color` |
| `$LIST_HEADER_BG_COLOR` | `$table-head-bg` |
| `$LIST_HEADER_FG_COLOR` | `$table-head-color` |

### 9. Alerts & Banners

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$BANNER_BORDER_RADIUS` | `$alert-border-radius` |

Alert colors are generated from semantic colors (`$success`, `$info`, etc.)

### 10. Modals

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$MENU_BG_COLOR` | `$modal-content-bg` |
| `$MENU_BORDER_COLOR` | `$modal-content-border-color` |

### 11. Tooltips

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$TOOLTIP_FG_COLOR` | `$tooltip-color` |
| `$TOOLTIP_BG_COLOR` | `$tooltip-bg` |

### 12. Progress Bars

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$PROGRESS_BG_COLOR` | `$progress-bg` |
| `$PROGRESS_FG_COLOR` | `$progress-bar-color` |
| `$PROGRESS_BAR_COLOR` | `$progress-bar-bg` |

### 13. List Groups

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$LIST_BG_COLOR` | `$list-group-bg` |
| `$LIST_BORDER_COLOR` | `$list-group-border-color` |
| `$LIST_HOVER_BG_COLOR` | `$list-group-hover-bg` |
| `$LINK_FG_COLOR` | `$list-group-action-color` |

### 14. Cards (Panels in BS3)

| MO Variable | Bootstrap 4 Variable |
|-------------|---------------------|
| `$LIST_BG_COLOR` | `$card-bg` |
| `$LIST_BORDER_COLOR` | `$card-border-color` |

## Unmapped Variables

The following MO theme variables don't have direct Bootstrap 4 equivalents and should be used in custom MO stylesheets:

### Link Styling
- `$LINK_WEIGHT` - Use custom CSS for font-weight on links
- `$LINK_BG_COLOR` - Bootstrap links are transparent by default
- `$LINK_VISITED_FG_COLOR` - Apply via `:visited` pseudo-class in custom CSS
- `$LINK_VISITED_BG_COLOR` - Apply via `:visited` pseudo-class in custom CSS
- `$LINK_HOVER_BG_COLOR` - Bootstrap links don't use background on hover

### Button States
- `$BUTTON_ACTIVE_FG_COLOR` - Use `:active` pseudo-class in custom CSS
- `$BUTTON_ACTIVE_BG_COLOR` - Use `:active` pseudo-class in custom CSS
- `$BUTTON_BORDER_STYLE` - Bootstrap always uses solid borders

### Form Controls
- `$INPUT_BORDER_STYLE` - Bootstrap always uses solid borders

### Borders
- `$BANNER_BORDER_WIDTH` - Maps to `$alert-border-width` (fixed at 2px)
- `$BANNER_BORDER_STYLE` - Bootstrap always uses solid borders
- `$ALERT_BORDER_WIDTH` - Maps to `$alert-border-width`
- `$ALERT_BORDER_STYLE` - Bootstrap always uses solid borders

### Custom MO Components
These are MO-specific components not part of Bootstrap:

- `$LOGO_*` - Logo styling (custom component)
- `$LEFT_BAR_*` - Left sidebar navigation (partially mapped to navbar-dark)
- `$TOP_BAR_*` - Top navigation bar (partially mapped to navbar-light)
- `$VOTE_METER_*` - Vote meter component (custom component)
- `$WELL_*` - Wells were removed in BS4; use `.bg-light` utility instead

## Migration Strategy

### Phase 1: Preparation (Current)
- ✅ All themes standardized to 121/121 variables
- ✅ Mapping file created
- 🔄 Documentation complete

### Phase 2: Testing
1. Test compilation with one theme (e.g., Agaricus)
2. Verify visual consistency with Bootstrap 3 version
3. Document any rendering differences

### Phase 3: Bootstrap 4 Migration
1. Update main stylesheet import order
2. Replace `bootstrap-sprockets` with Bootstrap 4
3. Replace `mo/map_theme_vars_to_bootstrap_vars` with `mo/map_theme_to_bootstrap4`
4. Update component usage for BS4 (panels → cards, etc.)
5. Test all themes

### Phase 4: Custom Component Updates
1. Update components using unmapped variables
2. Replace deprecated Bootstrap 3 components
3. Add new Bootstrap 4 utilities where appropriate

## Testing

To validate the mapping:

```bash
# Check SCSS compilation
bundle exec rails assets:precompile RAILS_ENV=test

# Run theme validation
script/validate_themes.rb
```

## Benefits

1. **Separation of Concerns**: Theme colors stay in theme files, Bootstrap config stays in mapping file
2. **Maintainability**: Changes to Bootstrap versions only require updating one mapping file
3. **Consistency**: All themes automatically work with Bootstrap 4 through semantic color mapping
4. **No Hardcoding**: All values come from theme variables, ensuring themes remain customizable

## References

- [Bootstrap 4 Theming Documentation](https://getbootstrap.com/docs/4.6/getting-started/theming/)
- [MO Theme System Analysis](./MO%20Theme%20System%20Analysis.md)
- GitHub Issue: [#3618 - Phase 5: Create Bootstrap 4 Mapping Layer](https://github.com/MushroomObserver/mushroom-observer/issues/3618)
