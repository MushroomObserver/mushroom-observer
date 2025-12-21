# Bootstrap Component Audit - Stream 1A Deliverable

**Date**: 2025-12-21
**Phase**: Phase 1, Stream 1A - Component Audit & Inventory
**Status**: ✅ Complete

## Executive Summary

Comprehensive audit of 444 ERB view files identified:
- **304 Bootstrap class usages** across 91 files
- **24 Bootstrap class patterns** actively used
- **52 Bootstrap 3-specific usages** requiring migration (17% of total)
- **15 file hotspots** accounting for majority of Bootstrap usage

## Key Findings

### Usage Distribution

| Category | Usages | % of Total | Priority |
|----------|--------|------------|----------|
| Grid (Layout) | 97 | 32% | 🔴 CRITICAL |
| Tables | 67 | 22% | 🔴 CRITICAL |
| Layout (Container/Row) | 54 | 18% | 🔴 CRITICAL |
| Forms | 42 | 14% | 🔴 CRITICAL |
| Utilities | 32 | 11% | 🟡 HIGH |
| Buttons | 12 | 4% | 🟡 HIGH |

**Key Insight**: Grid, Tables, Layout, and Forms account for 86% of all Bootstrap usage. These should be the first Phlex components created.

### Bootstrap 3-Specific Classes (Breaking Changes)

| Class | Usages | BS4 Replacement | Migration Impact |
|-------|--------|-----------------|------------------|
| `.col-xs-*` | 36 | `.col-*` | HIGH - Grid breakpoint change |
| `.btn-default` | 4 | `.btn-secondary` | LOW - Simple rename |
| `.hidden-xs` | 4 | `.d-none .d-sm-block` | MEDIUM - Visibility utilities |
| `.visible-xs` | 2 | `.d-block .d-sm-none` | MEDIUM - Visibility utilities |
| `.table-condensed` | 2 | `.table-sm` | LOW - Simple rename |
| `.visible-sm` | 1 | `.d-none .d-sm-block .d-md-none` | MEDIUM - Complex utility |
| `.pull-left` | 1 | `.float-left` | LOW - Simple rename |
| `.pull-right` | 1 | `.float-right` | LOW - Simple rename |
| `.help-block` | 1 | `.form-text` | LOW - Form helper |

**Total**: 52 usages requiring changes (17% of all Bootstrap usage)

**Migration Strategy**: Address these during Phlex component creation to ensure BS3/BS4 compatibility from the start.

## Phlex Component Migration Priority Matrix

### Tier 1: CRITICAL (Must Have for Phase 2) - Week 4-5

**Rationale**: These components account for 82% of all Bootstrap usage.

| Priority | Component | Usages | Files | Migration Complexity | Estimated Effort |
|----------|-----------|--------|-------|----------------------|------------------|
| 1 | `Components::Column` | 97 | ~35 | Medium | 2 days |
| 2 | `Components::Table` | 67 | ~25 | Low | 2 days |
| 3 | `Components::Row` | 39 | ~30 | Low | 1 day |
| 4 | `ApplicationForm::*Field` | 31 | ~20 | High | 3 days |
| 5 | `Components::Container` | 15 | ~12 | Low | 1 day |

**Week 4-5 Deliverable**: Complete grid system (Container, Row, Column), Tables, and basic form fields.

### Tier 2: HIGH (Phase 2 Completion) - Week 6-7

| Priority | Component | Usages | Files | Migration Complexity | Estimated Effort |
|----------|-----------|--------|-------|----------------------|------------------|
| 6 | `Components::Form` | 11 | ~8 | Medium | 2 days |
| 7 | `Components::Button` | 11 | ~10 | Low | 1 day |
| 8 | `Components::ButtonGroup` | 1 | 1 | Low | 0.5 days |

**Week 6-7 Deliverable**: Complete form components and button system.

### Tier 3: MEDIUM (Phase 3) - Week 8+

Components not heavily used but needed for completeness:
- Navigation components (when needed)
- Modal components (as required)
- Alert components (already exists)
- Badge/Label components (as required)
- Card/Panel components (when migrating)

**Week 8+ Strategy**: Create components on-demand as views are migrated.

## File Hotspots - High-Impact Targets

These 15 files contain 45% of all Bootstrap usage. Migrating these to Phlex provides maximum impact.

### Tier 1 Hotspots (Week 5-6)

| File | Bootstrap Usages | Primary Components | Migration Impact |
|------|------------------|-------------------|------------------|
| `observations/images/edit.html.erb` | 12 | Grid, Forms | HIGH |
| `interests/index.html.erb` | 11 | Tables, Grid | HIGH |
| `admin/blocked_ips/edit.html.erb` | 11 | Forms, Grid | MEDIUM |
| `locations/show/_coordinates.erb` | 9 | Grid | MEDIUM |
| `info/site_stats.html.erb` | 8 | Tables | MEDIUM |

**Week 5-6 Focus**: After creating core components, migrate these high-usage files first.

### Tier 2 Hotspots (Week 7-8)

| File | Bootstrap Usages | Primary Components | Migration Impact |
|------|------------------|-------------------|------------------|
| `locations/form/_show_locked.erb` | 7 | Grid | MEDIUM |
| `sequences/show.html.erb` | 7 | Tables | MEDIUM |
| `images/show/_vote_panel.html.erb` | 7 | Tables | LOW |
| `sequences/edit.html.erb` | 6 | Forms | MEDIUM |
| `sequences/new.html.erb` | 6 | Forms | MEDIUM |
| `herbaria/show.html.erb` | 6 | Tables | MEDIUM |
| `herbarium_records/edit.html.erb` | 6 | Forms | MEDIUM |
| `collection_numbers/new.html.erb` | 6 | Forms | MEDIUM |
| `herbarium_records/new.html.erb` | 6 | Forms | MEDIUM |
| `collection_numbers/edit.html.erb` | 6 | Forms | MEDIUM |

## ERB → Phlex Component Mapping

### View Type Patterns

**Index Views** (List pages):
- Pattern: Heavy table usage, grid layout
- Target: `Components::{Resource}::Index`
- Core components needed: Table, Container, Row, Column
- Examples: Contributors, Herbaria, Interests

**Show Views** (Detail pages):
- Pattern: Mixed grid, tables, and custom layouts
- Target: `Components::{Resource}::Show`
- Core components needed: Container, Row, Column, Table
- Examples: Sequences, Herbaria, Images

**Form Views** (Edit/New pages):
- Pattern: Heavy form field usage, grid layout
- Target: `ApplicationForm::*Field` with `Components::Form`
- Core components needed: All form fields, Container, Row, Column
- Examples: Collection Numbers, Herbarium Records, Sequences

**Partials**:
- Pattern: Highly variable, context-dependent
- Strategy: Extract reusable patterns into shared components
- Examples: Vote panels, coordinate displays, download forms

## Migration Roadmap

### Phase 2, Week 4-5: Foundation Components

**Goal**: Create the most-used components

```
✅ Priority 1-5 Components:
   - Components::Container
   - Components::Row
   - Components::Column
   - Components::Table
   - ApplicationForm::TextField
   - ApplicationForm::SelectField
   - ApplicationForm::CheckboxField
   - ApplicationForm::TextareaField
```

**Impact**: Enables migration of 82% of Bootstrap usage

### Phase 2, Week 6-7: Completion Components

**Goal**: Round out the component library

```
✅ Priority 6-8 Components:
   - Components::Form
   - Components::Button
   - Components::ButtonGroup
   - ApplicationForm remaining fields
```

**Impact**: Enables migration of 100% of identified Bootstrap usage

### Phase 3, Week 8-11: View Migration

**Goal**: Migrate high-traffic views to Phlex

**Week 8**: Tier 1 hotspots (observations, interests, admin)
**Week 9**: Tier 2 hotspots (locations, sequences, herbaria)
**Week 10**: Index views
**Week 11**: Show views and remaining partials

**Target**: 80%+ of traffic on Phlex components

## Bootstrap 3 → 4 Migration Considerations

### Components That Need BS3/BS4 Compatibility

During Phlex component creation (Weeks 4-7), build in BS3/BS4 compatibility:

1. **Components::Column**
   - BS3: `.col-xs-*`, `.col-sm-*`, `.col-md-*`, `.col-lg-*`
   - BS4: `.col-*`, `.col-sm-*`, `.col-md-*`, `.col-lg-*`, `.col-xl-*`
   - Strategy: Accept both, output based on Bootstrap version flag

2. **Components::Button**
   - BS3: `.btn-default`
   - BS4: `.btn-secondary`
   - Strategy: Map `variant: :default` → correct class based on version

3. **Components::Table**
   - BS3: `.table-condensed`
   - BS4: `.table-sm`
   - Strategy: Map `size: :condensed` → correct class based on version

4. **Utility Classes in Components**
   - BS3: `.pull-left`, `.pull-right`, `.hidden-*`, `.visible-*`
   - BS4: `.float-left`, `.float-right`, `.d-*` utilities
   - Strategy: Helper methods that output version-appropriate classes

### Testing Strategy

Each Phlex component should:
1. ✅ Render correctly with BS3 (current production)
2. ✅ Render correctly with BS4 (future migration)
3. ✅ Pass component specs
4. ✅ Pass visual regression tests

## Success Metrics

### Phase 2 (Week 7) Success Criteria

- [x] Audit complete (Stream 1A)
- [ ] 8 core Phlex components created
- [ ] All components BS3/BS4 compatible
- [ ] Component test coverage >95%
- [ ] 0 hotspot files migrated (baseline)

### Phase 3 (Week 11) Success Criteria

- [ ] 15 hotspot files migrated to Phlex
- [ ] 80%+ of Bootstrap usage in Phlex components
- [ ] Visual parity maintained
- [ ] Ready for BS4 deployment

## Next Steps

1. **Immediate** (Week 4):
   - Begin `Components::Container` implementation
   - Begin `Components::Row` implementation
   - Begin `Components::Column` implementation

2. **Week 4-5**:
   - Complete grid system
   - Create `Components::Table`
   - Start form field components

3. **Week 6-7**:
   - Complete form components
   - Create button components
   - Prepare for view migration

4. **Week 8+**:
   - Begin hotspot file migrations
   - Create BS4 compatibility layer
   - Conduct BS4 testing

## Appendices

### A. Full Bootstrap Class Usage Report

Generated by: `script/audit_bootstrap_usage.rb`

See script output for:
- Complete class-by-class breakdown
- File-by-file usage details
- Category-by-category analysis
- Phlex component recommendations

### B. Related Documentation

- [Bootstrap Upgrade Plan for MO](./bootstrap-upgrade-plan-for-mo.md) - Comprehensive 20-week plan
- [Theme Standardization Summary](./THEME_STANDARDIZATION_SUMMARY.md) - Completed foundation work
- [Bootstrap 4 Breaking Changes](./BOOTSTRAP4_BREAKING_CHANGES.md) - Migration reference

---

**Completed**: 2025-12-21
**Lead**: Nathan Wilson (@mo-nathan)
**Assisted by**: Claude Code

**Stream 1A Status**: ✅ COMPLETE

**Next Stream**: Stream 1C - Testing Infrastructure (in parallel with Phase 2 component development)
