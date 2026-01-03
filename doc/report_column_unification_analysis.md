# Report Column Unification Analysis

## Current Architecture

### How It Works Now
All reports inherit from `Report::BaseTable` and use the SAME base column set (0-25):
- **observation_selects** (11 columns): id, when, lat, lng, alt, specimen, is_collection_location, vote_cache, thumb_image_id, notes, updated_at
- **user_selects** (3 columns): id, login, name
- **name_selects** (4 columns): id, text_name, author, rank
- **location_selects** (8 columns): id, name, north, south, east, west, high, low

### The Problem
Two separate SQL queries are executed and concatenated:

```ruby
def all_rows
  rows_with_location + rows_without_location
end

def rows_with_location
  # observation + user + name + location (26 columns)
  query.scope.joins(:user, :location, :name).select(with_location_selects)
end

def rows_without_location
  # observation + user + name + blanks_for_location (26 columns)
  query.scope.joins(:user, :name).where(location_id: nil).select(without_location_selects)
end
```

### Where Misalignment Occurs
Race condition in parallel testing where:
1. Multiple workers build queries simultaneously
2. Frozen array concatenation (`observation_selects + user_selects + ...`) may not be thread-safe
3. Arel query building may have thread-safety issues
4. Result: Column indices occasionally shift by one position

Evidence from error logs:
```
Row data: [31426256, Sun, 24 Jun 2007, nil, nil, 0, 1, 0.0, nil,
           "---\n:Other: From somewhere else\n",  <-- This is @vals[9], should be String
           2007-06-24 09:00:01 UTC,                <-- This is @vals[10], but looks like updated_at
```

## Proposed Solution: Unified Column Set

### Option 1: Include All Extended Columns in Base Query

Create one universal column set that includes ALL columns any report might need:

```ruby
def unified_observation_selects
  base_observation_columns + optional_extended_columns
end

def optional_extended_columns
  [
    field_slip_subquery,      # Used by: Raw
    image_ids_subquery,       # Used by: Symbiota, Fundis
    collector_ids_subquery,   # Used by: Raw, Symbiota, Fundis, Mycoportal
    herbarium_subquery,       # Used by: Raw, Symbiota, Mycoportal
    sequence_ids_subquery     # Used by: Mycoportal
  ]
end
```

### Option 2: Keep Extended Columns Separate (Current + Fix)

Keep current architecture but fix thread-safety:
- Make array concatenation explicitly thread-safe
- Build queries once and cache them
- Ensure Arel query building happens in a mutex

## Pros and Cons Analysis

### Option 1: Unified Column Set

#### ✅ PROS

**1. Eliminates Race Conditions**
- Single query structure across all reports
- No dynamic array concatenation
- No variation in column ordering
- Thread-safe by design

**2. Simpler Mental Model**
- One source of truth for column positions
- Report::Row indices always mean the same thing
- Easier to debug - predictable structure

**3. Easier Maintenance**
- Add new columns in one place
- All reports automatically have access
- No need to override selects per report

**4. Better Testing**
- Deterministic behavior in parallel tests
- No intermittent failures
- Easier to write tests (known column positions)

**5. Potential Performance Benefits**
- Single query instead of concatenating two
- Could use SQL JOINs/subqueries more efficiently
- Fewer round trips to database (currently extended columns = separate queries!)

#### ❌ CONS

**1. Fetches Unused Data**
- Reports that don't need all columns still get them
- Example: Raw report gets image_ids even though it doesn't use them
- Wasted network bandwidth

**2. Query Complexity**
- More complex SQL with multiple LEFT JOINs or subqueries
- Could impact query planner efficiency
- Harder to optimize for specific report needs

**3. Memory Usage**
- Each Row object contains more data
- For large result sets (thousands of observations), memory footprint increases
- Example: 1000 observations × 5 extra columns × 50 bytes = ~250KB extra

**4. May Hide Performance Issues**
- "Just add it to the base query" becomes too easy
- Could lead to N+1 hidden in subqueries
- Harder to identify what each report actually needs

### Option 2: Current Architecture + Thread-Safety Fixes

#### ✅ PROS

**1. Performance Optimized**
- Each report only fetches what it needs
- Smaller result sets = less memory
- Faster for simple reports

**2. Flexible**
- Easy to add report-specific columns
- Can optimize queries per report type
- Clear separation of concerns

**3. Smaller Change**
- Less risky refactor
- Existing reports continue working
- Backwards compatible

#### ❌ CONS

**1. Complexity**
- Need to track down thread-safety issues
- Harder to reason about concurrent access
- May have other hidden race conditions

**2. Maintenance Burden**
- Each report manages its own extensions
- Need to understand column positions per report
- Easy to make mistakes with indices

**3. Doesn't Fix Root Cause**
- Treats symptoms, not disease
- Could have other similar issues lurking
- Defensive validation is still needed

## Performance Impact Estimation

### Current Test Data
- 84 observations in test database
- Average notes size: 17 bytes
- Typical report run: ~10-100 observations

### Estimated Impact of Unified Approach

**Additional Columns Per Row**:
- field_slip_code: ~20 bytes (when present)
- image_ids: ~50 bytes (multiple IDs)
- collector_ids: ~100 bytes (name + number combos)
- herbarium_data: ~80 bytes (code + accession)
- sequence_ids: ~30 bytes

**Total Extra Data**: ~280 bytes per row (worst case)

**For Typical Report (100 observations)**:
- Current: 26 columns × 50 bytes avg = 130KB
- Unified: 31 columns × 60 bytes avg = 186KB
- **Overhead**: ~56KB (43% increase)

**For Production (1000 observations)**:
- Current: ~1.3MB
- Unified: ~1.86MB
- **Overhead**: ~560KB

### Network Transfer Time
At 100 Mbps (typical network):
- 560KB = 0.045 seconds
- **Negligible for most use cases**

### Query Performance
- Additional LEFT JOINs may slow query by 10-30%
- BUT: Currently doing 5 separate queries for extended columns
- Unified approach could be FASTER overall by consolidating queries

## Recommendation

**Implement Option 1: Unified Column Set**

### Why This Makes Sense

1. **The extended columns are ALREADY fetched separately**
   - Current code does 1 base query + up to 5 additional queries
   - Unifying into 1 query could actually IMPROVE performance

2. **The base columns are already uniform**
   - Problem is in HOW they're constructed, not WHAT they contain
   - Unification fixes the construction problem

3. **Performance cost is minimal**
   - ~56KB overhead for 100 observations
   - Offset by reducing 5 queries to 1
   - Network cost is negligible

4. **Huge maintainability win**
   - Eliminates entire class of bugs
   - Makes parallel testing reliable
   - Easier for developers to understand

5. **Enables future optimizations**
   - Can tune one query instead of many
   - Easier to add caching
   - Simpler to profile and optimize

### Implementation Strategy

1. **Phase 1**: Add extended columns to base selects as LEFT JOINs/subqueries
2. **Phase 2**: Update reports to use unified column positions
3. **Phase 3**: Remove extend_data! methods and separate queries
4. **Phase 4**: Verify all tests pass, measure performance
5. **Phase 5**: Remove defensive validation (no longer needed)

### Risk Mitigation

- Implement behind feature flag
- A/B test in production
- Monitor query performance
- Roll back if issues arise
- Keep defensive validation temporarily

## Conclusion

While the unified approach adds some overhead (~43% more data), it:
- **Eliminates race conditions completely**
- **Simplifies architecture significantly**
- **May actually improve performance** (fewer queries)
- **Makes codebase more maintainable**

The performance cost is minimal and acceptable given the reliability and maintainability benefits.
