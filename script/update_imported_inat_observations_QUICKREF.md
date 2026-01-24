# Quick Reference: Update Imported iNat Observations

## Basic Syntax

```bash
bin/rails runner script/update_imported_inat_observations.rb 'QUERY' USER_ID
```

## Common Commands

### Test with 5 observations
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where.not(inat_id: nil).limit(5)' 0
```

### Update recent imports (last 24 hours)
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where("created_at > ? AND inat_id IS NOT NULL", 1.day.ago)' 0
```

### Update specific project observations
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.projects(PROJECT_ID).where.not(inat_id: nil)' 0
```

### Update specific observation IDs
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where(id: [123, 456, 789])' 0
```

### Update observations by user
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'User.find_by(login: "username").observations.where.not(inat_id: nil)' 0
```

### Update observations with notes containing text
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where.not(inat_id: nil).notes_has("User: johnplischke")' 0
```

### Update observations created in date range
```bash
bin/rails runner script/update_imported_inat_observations.rb \
  'Observation.where("created_at BETWEEN ? AND ? AND inat_id IS NOT NULL", "2024-01-01", "2024-12-31")' 0
```

## What Gets Updated

| Data Type | Source | Destination | Condition |
|-----------|--------|-------------|-----------|
| Proposed Names | iNat `identifications` | MO Namings | If name exists in MO & not already proposed |
| Provisional Names | iNat "Provisional Species Name" field | MO observation notes | If not already proposed or in notes |
| DNA Sequences | iNat observation fields (datatype: dna) | MO Sequences | If locus+bases not already in observation |

## Output Summary

The script prints:
- Progress for each observation
- Summary with counts:
  - Observations processed
  - Namings added
  - Provisional names added
  - Sequences added
  - Errors (if any)

## Tips

1. **Always test first** with `.limit(5)` on a small dataset
2. **Use user ID 0** (admin) or a dedicated bot user for attribution
3. **Check summary** for unexpected skips or errors
4. **Large datasets**: Break into batches with `.limit()` and `.offset()`
5. **Rate limiting**: Script respects iNat API limits (1 sec delay between requests)

## Common Queries

### Observations with inat_id
```ruby
'Observation.where.not(inat_id: nil)'
```

### Recent observations
```ruby
'Observation.where("created_at > ?", 1.week.ago).where.not(inat_id: nil)'
```

### Observations from project
```ruby
'Observation.projects(389).where.not(inat_id: nil)'
```

### Observations with few namings
```ruby
'Observation.where.not(inat_id: nil).joins(:namings).group("observations.id").having("COUNT(namings.id) < 3")'
```

### Specific IDs
```ruby
'Observation.where(id: [123, 456, 789])'
```

## Error Handling

- Script continues on errors
- Errors collected in summary
- Individual observations can fail without affecting others

## Files

- **Script**: `script/update_imported_inat_observations.rb`
- **Full docs**: `script/update_imported_inat_observations_README.md`
- **Summary**: `script/update_imported_inat_observations_SUMMARY.md`
- **This file**: `script/update_imported_inat_observations_QUICKREF.md`

## Related Scripts

- `tmp/find_modified_inat_observations.rb` - Reports which iNat observations have been modified
