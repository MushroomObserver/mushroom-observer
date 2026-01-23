# Update Imported iNat Observations Script

## Overview

This Rails runner script updates key data in imported MO observations based on their corresponding iNaturalist observations. It's designed to sync changes from iNat that occurred after the initial import.

## What It Updates

The script updates three types of data:

1. **Proposed Names (Namings)** - From iNat suggested identifications
   - Only adds if the name (or a synonym) hasn't already been proposed
   - Requires the name to exist in MO's database

2. **Provisional Names** - From iNat "Provisional Species Name" observation field
   - Only adds if not already proposed as a regular name
   - Adds to observation notes

3. **Sequences** - From iNat observation fields with DNA data
   - Extracts sequences from fields with `datatype: "dna"` or names containing "DNA"
   - Only adds if the same locus+bases combination doesn't already exist

## Usage

```bash
bin/rails runner script/update_imported_inat_observations.rb 'AR_SEARCH_STRING' [USER_ID]
```

### Arguments

- `AR_SEARCH_STRING` (required) - ActiveRecord query to find observations to update
- `USER_ID` (optional) - User ID to attribute new records to (default: 0)

### Examples

Update 10 observations with inat_id:
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where.not(inat_id: nil).limit(10)' 0
```

Update observations from a specific project:
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.projects(389).where.not(inat_id: nil)' 123
```

Update observations with notes containing specific text:
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where.not(inat_id: nil).notes_has("User: johnplischke")' 0
```

Update recently created observations:
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where.not(inat_id: nil).where("created_at > ?", 1.week.ago)' 0
```

## How It Works

### 1. Fetch iNat Data

- Uses the iNat API to fetch detailed observation data
- Batches requests (200 observations per batch)
- Respects rate limiting (1 second delay between requests)

### 2. Process Each Observation

For each MO observation:

#### A. Process Identifications

- Extracts all identifications from iNat observation
- For each identification:
  - Looks up the taxon name in MO's database
  - Checks if the name (or a synonym) has already been proposed
  - If not, creates a new Naming record
  - Attributes it to the specified user
  - Adds a reason note citing the iNat identifier and date

#### B. Process Provisional Names

- Looks for "Provisional Species Name" observation field
- Checks if it's already proposed as a regular name
- If not, adds it to the observation's notes with attribution

#### C. Process Sequences

- Finds all observation fields containing DNA sequence data
- For each sequence:
  - Extracts locus (field name) and bases (field value)
  - Checks if a sequence with the same locus+bases already exists
  - If not, creates a new Sequence record
  - Attributes it to the specified user

#### D. Update Consensus

- Recalculates the observation's naming consensus
- Updates the cached consensus name

### 3. Report Results

Prints a summary showing:
- Observations processed
- Namings added
- Provisional names added
- Sequences added
- Any errors encountered

## Important Notes

### Name Matching

The script will **skip** iNat identifications if:
- The taxon name doesn't exist in MO's database
- The name (or a synonym) has already been proposed for the observation

This is intentional to avoid:
- Creating invalid names
- Duplicate proposals
- Cluttering observations with redundant identifications

### User Attribution

All new records (Namings, Sequences) are attributed to the user specified by `USER_ID`.

**Important:** Use user ID `0` (admin) or a dedicated "bot" user for automated imports. This makes it clear these are automated additions, not manual identifications.

### Provisional Names

Provisional names are added to the `notes[:Other]` field, not as regular proposed names. This is because:
- MO doesn't have a dedicated provisional name field
- Provisional names are often informal or temporary
- They should be visible but distinct from formal identifications

### Sequences

The script only handles sequences from observation fields. It does **not**:
- Parse GenBank/NCBI accession numbers from notes
- Fetch sequence data from external repositories
- Handle linked sequences (archive + accession without bases)

If iNat has sequences with only accession numbers, you'll need to enhance the script or handle those manually.

### Rate Limiting

The script includes delays between API requests to respect iNat's rate limits:
- 1 second between batches
- 1 second between paginated requests

For large datasets, this can take considerable time. Plan accordingly.

## Error Handling

The script:
- Continues processing if one observation fails
- Collects all errors for the summary report
- Prints detailed error messages
- Does not roll back successful updates if later observations fail

## Testing

Before running on production data, test with:

1. **Small dataset**: Use `.limit(5)` to test on a few observations
2. **Known data**: Use observations you can verify manually
3. **Dry-run check**: Review the summary to ensure expected behavior

Example test run:
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where(id: [123, 456, 789])' 0
```

## Troubleshooting

### "User with id X not found"

- Ensure the user ID exists in the database
- Use `User.find(id)` in rails console to verify

### "Name 'X' not found in MO database, skipping"

- This is normal for taxa not yet in MO
- Consider importing the name first if it's valid
- Or skip these identifications (they'll remain on iNat)

### "Failed to add naming/sequence"

- Check validation errors in the summary
- Common issues:
  - Invalid name_id
  - Duplicate naming (shouldn't happen with checks, but possible with race conditions)
  - Invalid sequence format (bases must be valid nucleotide codes)

### API request failures

- Network issues or iNat API downtime
- The script will warn and continue with other observations
- Re-run the script later for failed observations

## Performance Considerations

### For Large Datasets

If updating many observations (>1000):

1. **Run in batches**: Break query into smaller chunks
   ```bash
   bin/rails runner script/update_imported_inat_observations.rb \
     'Observation.where.not(inat_id: nil).limit(100).offset(0)' 0

   bin/rails runner script/update_imported_inat_observations.rb \
     'Observation.where.not(inat_id: nil).limit(100).offset(100)' 0
   ```

2. **Use background job**: Consider wrapping in a job for better monitoring

3. **Monitor database**: Watch for slow queries, especially on observations with many namings

### Database Queries

The script preloads associations where possible, but may still generate N+1 queries for:
- Name lookups
- Synonym checks
- Existing naming/sequence checks

For very large datasets, consider adding database indices or optimizing these checks.

## Related Scripts

- `tmp/find_modified_inat_observations.rb` - Reports which observations have been modified on iNat (this script's companion)

## Future Enhancements

Possible improvements:
- Parse GenBank accession numbers from observation field values
- Handle external repository links (archive + accession)
- Add option to create votes for new namings
- Add option to update observation notes/location if changed on iNat
- Progress bar for long-running operations
- Export detailed log to file

## Contact

For issues or questions, file an issue on GitHub or contact the Mushroom Observer development team.
