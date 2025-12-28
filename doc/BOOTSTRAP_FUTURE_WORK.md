# Bootstrap Migration - Future Work

## Status

Theme standardization (Phases 1-5) is **COMPLETE**. Bootstrap migration work is **NOT YET STARTED**.

## When Bootstrap Migration Will Happen

Bootstrap 3 → 4 → 5 migration is planned for **Phase 3 onwards** of the comprehensive modernization plan:

- **Phase 3 (Weeks 8-11)**: Bootstrap 4 preparation + Phlex view migration
  - Week 8-9: Create BS4 compatibility layer in Phlex components
  - Week 9: Use `mo/_map_theme_to_bootstrap4.scss` mapping
  - Week 10-11: BS4 integration testing

- **Phase 4 (Weeks 12-14)**: Bootstrap 4 deployment
  - Staged rollout with feature flags
  - Cleanup and optimization

- **Phase 5 (Weeks 15-17)**: Bootstrap 5 preparation
  - jQuery removal
  - BS5 component updates
  - BS5 theme mapping

- **Phase 6 (Weeks 18-20)**: Bootstrap 5 deployment
  - Final migration and polish

## Prerequisites Before Starting

Before Bootstrap migration can begin, we need:

1. ✅ **Theme standardization complete** (Phases 1-5) - DONE
2. ⏳ **Core Phlex components created** (Phase 2, weeks 4-7) - TODO
3. ⏳ **High-traffic views migrated to Phlex** (Phase 3, weeks 8-11) - TODO

## Why Phlex First?

The comprehensive plan uses a **Phlex-first approach** because:

- Phlex components can include BS3/BS4 compatibility logic
- Migrating views to Phlex first makes Bootstrap migration 40% easier
- Allows testing BS4 changes in isolated components
- Reduces risk by separating view migration from CSS framework migration

## Available Resources

### Theme Mapping (Ready for Phase 3)
- `app/assets/stylesheets/mo/_map_theme_to_bootstrap4.scss` - Complete BS4 variable mapping
- `app/assets/stylesheets/mo/_map_theme_vars_to_bootstrap_vars.scss` - Current BS3 mapping

### Breaking Changes Reference (Ready for Phase 3)
- `doc/BOOTSTRAP4_BREAKING_CHANGES.md` - Comprehensive catalog of BS3→BS4 changes
- `doc/BOOTSTRAP4_THEME_MAPPING.md` - Theme variable mapping documentation

### Comprehensive Plan
- `doc/Bootstrap Upgrade Plan for MO.md` - Full 20-week modernization plan

## Current Focus

**Focus now on Phase 2**: Creating core Phlex components (Alert, Card, Button, Forms, etc.)

Bootstrap migration work will resume in **8-11 weeks** after Phlex infrastructure is in place.

---

**Last Updated**: 2025-12-21
**See**: [Bootstrap Upgrade Plan for MO](./Bootstrap%20Upgrade%20Plan%20for%20MO.md)
