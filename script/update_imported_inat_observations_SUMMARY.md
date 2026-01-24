# Update Imported iNat Observations Script - Summary

## Files Created

### 1. `script/update_imported_inat_observations.rb`

Main Rails runner script that updates MO observations with data from iNaturalist.

**Key Features:**
- Fetches iNat observations via API
- Adds proposed names from iNat suggested identifications
- Adds provisional names from iNat observation fields
- Imports DNA sequences from iNat observation fields
- Validates all data before adding
- Provides detailed progress reporting
- RuboCop compliant (no violations)

### 2. `script/update_imported_inat_observations_README.md`

Comprehensive documentation covering:
- What the script updates
- Usage examples
- How it works internally
- Important notes and caveats
- Troubleshooting guide
- Performance considerations

### 3. `script/update_imported_inat_observations_SUMMARY.md`

This summary file.

## Quick Start

```bash
# Update a small set of observations (testing)
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where.not(inat_id: nil).limit(5)' 0

# Update observations from a specific project
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.projects(389).where.not(inat_id: nil)' 123

# Update recently created observations
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where.not(inat_id: nil).where("created_at > ?", 1.week.ago)' 0
```

## What Gets Updated

### 1. Proposed Names (Namings)

- Extracted from iNat's `identifications` array
- Each identification becomes a Naming in MO
- Only added if:
  - The taxon name exists in MO's database
  - Neither the name nor a synonym has been proposed
- Includes attribution to the iNat identifier in the reasons

### 2. Provisional Names

- Extracted from "Provisional Species Name" observation field
- Added to observation's notes as formatted text
- Only added if:
  - Not already proposed as a regular name
  - Not already in the notes

### 3. Sequences

- Extracted from observation fields with DNA data
- Identifies fields by:
  - `datatype: "dna"` attribute
  - Field name containing "DNA" + value starting with nucleotide codes
- Only added if:
  - Same locus+bases combination doesn't already exist
- Includes locus (field name) and bases (sequence data)

## Architecture & Design

### Code Structure

The script follows these principles:
- Small, focused methods (complies with RuboCop metrics)
- Clear separation of concerns
- Detailed error handling
- Progress tracking

### Key Methods

- `fetch_inat_observations()` - API fetching with batching and rate limiting
- `process_observation()` - Main processing logic
- `process_identifications()` - Handles suggested IDs
- `process_provisional_name()` - Handles provisional names
- `process_sequences()` - Handles DNA sequences
- `create_naming()` / `create_sequence()` - Record creation

### Error Handling

- Continues processing on errors
- Collects all errors for summary
- Detailed error messages
- No rollback (successful updates persist)

## Data Validation

### Name Lookup

1. Tries exact match on `text_name`
2. Tries normalized match on `search_name`
3. Skips if not found (doesn't create invalid names)

### Synonym Detection

- Checks if any synonym of the proposed name has already been proposed
- Prevents duplicate proposals via synonyms

### Sequence Validation

- Normalizes bases (removes whitespace, uppercase) for comparison
- Checks for exact duplicates by locus+bases
- Validates sequence format via Sequence model

## Performance

### API Rate Limiting

- 1 second delay between batches (200 observations per batch)
- 1 second delay between paginated requests
- Respectful of iNat's API limits

### Database Optimization

- Preloads associations where possible
- May still have N+1 queries for:
  - Name lookups
  - Synonym checks
  - Existing record checks

### Scaling

For large datasets (>1000 observations):
- Consider running in batches with `.limit()` and `.offset()`
- Monitor database performance
- Consider background job for very large updates

## Testing Recommendations

Before production use:

1. **Test with small dataset** (5-10 observations)
   ```bash
   bin/rails runner script/update_imported_inat_observations.rb \
     'Observation.where.not(inat_id: nil).limit(5)' 0
   ```

2. **Verify results** in MO UI:
   - Check namings were added correctly
   - Verify provisional names in notes
   - Confirm sequences are present

3. **Review summary output**:
   - Confirm expected counts
   - Check for any errors
   - Validate skipped names are intentional

## Common Use Cases

### Update Recently Imported Observations

```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where("created_at > ? AND inat_id IS NOT NULL", 1.day.ago)' 0
```

### Update Observations from Specific User

```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'User.find_by(login: "username").observations.where.not(inat_id: nil)' 0
```

### Update Observations with Few Namings

```bash
# Find observations that might be missing iNat suggestions
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where.not(inat_id: nil).joins(:namings).group("observations.id").having("COUNT(namings.id) < 3")' 0
```

### Update Specific Observation IDs

```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where(id: [123, 456, 789])' 0
```

## Comparison with Original Script

Based on `tmp/find_modified_inat_observations.rb`:

| Feature | Original | New Script |
|---------|----------|------------|
| Finds modified iNat obs | ✓ | ✓ |
| Generates CSV report | ✓ | ✗ |
| Updates MO observations | ✗ | ✓ |
| Adds namings | ✗ | ✓ |
| Adds provisional names | ✗ | ✓ |
| Imports sequences | ✗ | ✓ |

The new script is **complementary** to the original:
- Original: **Reports** what changed on iNat
- New: **Updates** MO with changes from iNat

## Limitations

### Name Availability

- Only adds names that exist in MO's database
- Skips iNat taxa not yet in MO
- Does not create new Name records

### Sequence Handling

- Only handles inline sequence data (bases in field value)
- Does not parse GenBank accession numbers
- Does not fetch sequences from external repositories
- Archive and accession fields are left empty

### Provisional Names

- Added to notes, not as a dedicated field
- Simple text append, no structured data

## Future Enhancements

Possible improvements:
- Parse GenBank/NCBI accession numbers from field values
- Fetch sequence data from external repositories
- Add votes for new namings
- Update observation location/notes if changed on iNat
- Progress bar for long operations
- Export detailed log file
- Dry-run mode to preview changes

## Related Files

- `tmp/find_modified_inat_observations.rb` - Reports modified iNat observations
- `app/classes/inat/obs.rb` - iNat observation data parser
- `app/classes/inat/mo_observation_builder.rb` - MO observation builder
- `app/models/naming.rb` - Naming model
- `app/models/sequence.rb` - Sequence model

## Support

For issues, questions, or enhancement requests:
- File an issue on GitHub
- Contact the Mushroom Observer development team
- Check `script/update_imported_inat_observations_README.md` for detailed documentation
