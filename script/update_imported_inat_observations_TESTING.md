# Testing Guide: Update Imported iNat Observations

## Overview

The observation updater has been refactored into a testable class structure, making it easy to write unit tests for all functionality.

## Architecture

### Class Structure

```
app/classes/inat/
├── observation_updater.rb              # Main updater class
└── observation_updater/
    └── statistics.rb                   # Statistics tracking class

script/
└── update_imported_inat_observations.rb # CLI wrapper script

test/classes/inat/
└── observation_updater_test.rb         # Unit tests
```

### Key Classes

#### `Inat::ObservationUpdater`

Main class that handles updating MO observations from iNat data.

**Usage:**
```ruby
observations = Observation.where.not(inat_id: nil).limit(10)
user = User.find(0)

updater = Inat::ObservationUpdater.new(observations, user)
stats = updater.run

puts "Processed: #{stats.observations_processed}"
puts "Namings added: #{stats.namings_added}"
puts "Errors: #{stats.error_count}"
```

**Public Methods:**
- `initialize(observations, user)` - Create new updater
- `run` - Execute the update process
- `stats` - Access statistics object

**Private Methods (testable via `send`):**
- `find_or_skip_name(taxon_name)` - Find MO name for iNat taxon
- `name_already_proposed?(obs, name)` - Check if name proposed
- `build_naming(obs, name, ident)` - Create Naming object
- `build_sequence(obs, locus, bases)` - Create Sequence object
- `sequence_already_exists?(obs, locus, bases)` - Check for duplicates
- `provisional_name_in_notes?(obs, prov_name)` - Check notes
- And many more...

#### `Inat::ObservationUpdater::Statistics`

Tracks statistics and details during the update process.

**Usage:**
```ruby
stats = Inat::ObservationUpdater::Statistics.new
stats.increment(:namings_added)
stats.add_error("Something went wrong")
stats.add_detail("Added naming: Agaricus campestris")

puts stats.namings_added        # => 1
puts stats.error_count          # => 1
puts stats.errors              # => ["Something went wrong"]
puts stats.details             # => ["Added naming: Agaricus campestris"]
```

**Public Methods:**
- `increment(counter)` - Increment a counter (:observations_processed, :namings_added, etc.)
- `add_error(message)` - Add an error message
- `add_detail(message)` - Add a detail message
- `error_count` - Get count of errors

## Running Tests

### Run All Updater Tests

```bash
bin/rails test test/classes/inat/observation_updater_test.rb
```

### Run Specific Test

```bash
bin/rails test test/classes/inat/observation_updater_test.rb \
  -n test_find_or_skip_name_with_existing_name
```

### Current Test Coverage

The test suite includes 11 tests covering:

1. **Statistics initialization** - Verifies counters start at zero
2. **Name finding** - Tests exact and normalized name matching
3. **Name lookup failures** - Handles non-existent names gracefully
4. **Duplicate detection** - Checks if name already proposed
5. **Naming creation** - Builds correct Naming objects
6. **Sequence creation** - Builds correct Sequence objects
7. **Sequence duplicate detection** - Prevents duplicate sequences
8. **Provisional name detection** - Checks notes for existing names

### Test Results

All 11 tests pass:
```
Finished in 2.36s
11 tests, 42 assertions, 0 failures, 0 errors, 0 skips
```

## Writing New Tests

### Testing Private Methods

Use `send` to test private methods:

```ruby
def test_my_private_method
  obs = observations(:minimal_unknown_obs)
  user = users(:rolf)
  updater = Inat::ObservationUpdater.new([obs], user)

  result = updater.send(:my_private_method, arg1, arg2)

  assert_equal(expected, result)
end
```

### Mocking API Calls

For tests that need to mock iNat API responses, stub the HTTP calls:

```ruby
def test_fetch_inat_observations_with_mock
  obs = observations(:minimal_unknown_obs)
  user = users(:rolf)
  updater = Inat::ObservationUpdater.new([obs], user)

  # Mock the API response
  mock_response = {
    results: [
      {
        id: obs.inat_id,
        identifications: [...],
        ofvs: [...]
      }
    ],
    total_results: 1
  }

  # Use WebMock or similar to stub HTTP calls
  # Then call updater.run and verify results
end
```

### Testing Statistics

Test statistics tracking directly:

```ruby
def test_statistics_tracking
  stats = Inat::ObservationUpdater::Statistics.new

  stats.increment(:namings_added)
  stats.increment(:namings_added)
  stats.add_error("Test error")

  assert_equal(2, stats.namings_added)
  assert_equal(1, stats.error_count)
  assert_includes(stats.errors, "Test error")
end
```

### Testing with Fixtures

Use existing test fixtures:

```ruby
def test_with_existing_observation
  # Observations with namings
  obs = observations(:coprinus_comatus_obs)

  # Observations without namings
  obs = observations(:minimal_unknown_obs)

  # Observations with sequences
  obs = observations(:genbanked_obs)

  # Users
  user = users(:rolf)
  user = users(:mary)

  # Names
  name = names(:coprinus_comatus)
  name = names(:agaricus_campestris)
end
```

## Benefits of Testable Structure

### Before (Script with Top-Level Methods)

❌ Hard to test without running entire script
❌ Requires ARGV manipulation in tests
❌ Global state with `@stats` variable
❌ Can't easily test private methods
❌ Script executes on load

### After (Class-Based Structure)

✓ Easy to instantiate and test
✓ No ARGV needed for unit tests
✓ Statistics object is self-contained
✓ Private methods testable via `send`
✓ Script only executes when run directly
✓ Can reuse class in other contexts (rake tasks, jobs, etc.)

## Using the Class Outside the Script

The `Inat::ObservationUpdater` class can be used in other contexts:

### In a Rake Task

```ruby
# lib/tasks/inat_sync.rake
namespace :inat do
  desc "Sync recent iNat imports"
  task sync_recent: :environment do
    observations = Observation.where("created_at > ?", 1.day.ago)
                              .where.not(inat_id: nil)
    user = User.find(0)

    updater = Inat::ObservationUpdater.new(observations, user)
    stats = updater.run

    puts "Updated #{stats.observations_processed} observations"
    puts "Added #{stats.namings_added} namings"
  end
end
```

### In a Background Job

```ruby
class InatSyncJob < ApplicationJob
  queue_as :default

  def perform(observation_ids, user_id)
    observations = Observation.where(id: observation_ids)
    user = User.find(user_id)

    updater = Inat::ObservationUpdater.new(observations, user)
    stats = updater.run

    # Log results
    Rails.logger.info("Synced #{stats.observations_processed} observations")
  end
end
```

### In Rails Console

```ruby
# Find observations to update
obs = Observation.projects(389).where.not(inat_id: nil).limit(5)
user = User.find(0)

# Run updater
updater = Inat::ObservationUpdater.new(obs, user)
stats = updater.run

# Check results
stats.observations_processed  # => 5
stats.namings_added          # => 12
stats.sequences_added        # => 3
stats.errors                 # => []
```

## Code Quality

All code passes RuboCop with no violations:

```bash
bundle exec rubocop app/classes/inat/observation_updater.rb \
  app/classes/inat/observation_updater/statistics.rb \
  script/update_imported_inat_observations.rb \
  test/classes/inat/observation_updater_test.rb

# Result: 4 files inspected, no offenses detected
```

## Future Test Enhancements

Potential areas for additional test coverage:

1. **Integration tests** - Test with actual iNat API calls (using VCR)
2. **API error handling** - Test network failures, timeouts, invalid JSON
3. **Complex identifications** - Test with multiple identifications per observation
4. **Synonym handling** - Test name synonym detection edge cases
5. **Sequence validation** - Test various sequence formats and invalid bases
6. **Concurrent updates** - Test thread safety (after fixing User.current)
7. **Large datasets** - Test performance with many observations

## Resources

- Main class: [app/classes/inat/observation_updater.rb](app/classes/inat/observation_updater.rb)
- Statistics: [app/classes/inat/observation_updater/statistics.rb](app/classes/inat/observation_updater/statistics.rb)
- Tests: [test/classes/inat/observation_updater_test.rb](test/classes/inat/observation_updater_test.rb)
- Script: [script/update_imported_inat_observations.rb](script/update_imported_inat_observations.rb)
- Quick Reference: [script/update_imported_inat_observations_QUICKREF.md](script/update_imported_inat_observations_QUICKREF.md)
