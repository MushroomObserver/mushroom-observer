---
paths: test/**/*.rb
---

# Rails Testing Conventions

## Test Execution Syntax

**IMPORTANT: Rails uses MiniTest, not RSpec syntax**

### Correct Syntax
```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/observation_test.rb

# Run specific test by name (use -n flag, NOT ::ClassName#method)
bin/rails test test/models/observation_test.rb -n test_scope_needs_naming

# Run specific system test by name (use -n flag, NOT ::ClassName#method)
bin/rails test test/system/observation_form_system_test.rb -n test_commit_form

# Run with verbose output
bin/rails test test/models/observation_test.rb -v

# Run controller tests
bin/rails test:controllers

# Run with coverage
bin/rails test:coverage
bundle exec rails test:coverage
rake test:coverage
```

### Incorrect Syntax (DO NOT USE)
```bash
# ❌ WRONG - This is RSpec syntax, not Rails
bin/rails test test/models/observation_test.rb::ObservationTest#test_name -v
# ❌ This will cause LoadError: cannot load such file

# ❌ WRONG - This will run the whole system test suite, not the file specified
bin/rails test:system test/system/help_identify_system_test.rb
```

## Test Structure
- Framework: MiniTest (not RSpec)
- Test files: `test/**/*_test.rb`
- Fixtures: `test/fixtures/`
- System tests: Capybara-based

## Common Assertions
- `assert(condition)`
- `assert_equal(expected, actual)`
- `assert_includes(collection, item)`
- `assert_nil(value)`
- `assert_response(:success)`

## Running Specific Test Suites
- All tests: `bin/rails test`
- Controllers: `bin/rails test:controllers`
- Models: `bin/rails test test/models/`
- Coverage: `bin/rails test:coverage`
