# Parallel Testing Best Practices

## Overview

Mushroom Observer uses Rails 7's built-in parallel testing to speed up test execution. Tests run concurrently across multiple worker processes, each with its own database and isolated resources. This document outlines best practices for writing parallel-safe tests.

## How Parallel Testing Works

Rails 7 parallel testing:
- Spawns multiple worker processes (one per CPU core by default)
- Each worker gets its own database: `mo_test-0`, `mo_test-1`, `mo_test-2`, etc.
- Workers are isolated from each other but tests within a worker share the same thread
- Configured in `test/test_helper.rb` with a threshold of 50 tests (files with <50 tests run serially)

## Running Tests

### Parallel Mode (Default)
```bash
rails test                           # All tests in parallel
PARALLEL_TEST_THRESHOLD=0 rails test # Force parallel even for small test files
```

### Serial Mode (For Debugging)
```bash
rails test test/path/to/test.rb           # Single file (if <50 tests)
rails test test/path/to/test.rb:45        # Specific test (always serial)
PARALLEL_TEST_THRESHOLD=999999 rails test # Force all tests serial
```

## Common Pitfalls and Solutions

### 1. Shared File System Resources

**Problem**: Multiple workers writing to the same file paths cause conflicts.

**❌ Bad - Hardcoded paths**
```ruby
def test_export_data
  output_file = "/tmp/export.csv"
  exporter.export(output_file)
  assert File.exist?(output_file)
end
```

**✅ Good - Use Tempfile**
```ruby
def test_export_data
  tempfile = Tempfile.new("export").path
  exporter.export(tempfile)
  assert File.exist?(tempfile)
end
```

**✅ Good - Worker-specific paths**
```ruby
# For files that must have specific names
def test_export_data
  worker_num = database_worker_number || "0"
  output_file = "/tmp/export-#{worker_num}.csv"
  exporter.export(output_file)
  assert File.exist?(output_file)
end
```

### 2. Thread-Local vs Class Variables

**Problem**: Class variables are shared across all threads in a worker, causing test pollution.

**❌ Bad - Class variable**
```ruby
class User
  @@current_user = nil  # Shared across tests in same worker!

  def self.current=(user)
    @@current_user = user
  end
end
```

**✅ Good - Thread-local storage**
```ruby
class User
  def self.current=(user)
    Thread.current[:mushroom_observer_user] = user  # Isolated per thread
  end

  def self.current
    Thread.current[:mushroom_observer_user]
  end
end
```

**Important**: Always clear thread-local storage in test setup/teardown:
```ruby
setup do
  Thread.current[:mushroom_observer_user] = nil
end

teardown do
  Thread.current[:mushroom_observer_user] = nil
end
```

### 3. Database Worker Detection

**Problem**: Code needs to know which worker it's running in to use correct resources.

**✅ Use `database_worker_number` helper**
```ruby
# Available in all test cases via GeneralExtensions
include GeneralExtensions

def test_worker_specific_operation
  worker_num = database_worker_number  # Returns "0", "1", "2", etc., or nil
  config_file = Rails.root.join("config/mysql-test-#{worker_num}.cnf")
  # ...
end
```

This helper extracts the worker number from the database name (e.g., `mo_test-7` → `"7"`).

### 4. Calling Bash Scripts from Tests

**Problem**: Scripts need to connect to the correct worker-specific database.

**❌ Bad - No environment configuration**
```ruby
def test_script_that_queries_database
  system("script/lookup_user dick > output.txt")
  # Script connects to mo_test instead of mo_test-3!
end
```

**✅ Good - Pass worker-specific config**
```ruby
include GeneralExtensions

def script_env
  worker_num = database_worker_number
  if worker_num
    config_file = Rails.root.join("config/mysql-test-#{worker_num}.cnf")
    { "MO_MYSQL_CONFIG" => config_file.to_s, "RAILS_ENV" => "test" }
  else
    { "RAILS_ENV" => "test" }
  end
end

def test_script_that_queries_database
  tempfile = Tempfile.new("test").path
  cmd = "script/lookup_user dick > #{tempfile}"
  assert system(script_env, cmd)
  # Script now connects to correct worker database
end
```

**Note**: Scripts must check `MO_MYSQL_CONFIG` environment variable (see `script/bash_include`).

### 5. Image Files and Worker Isolation

The image system automatically handles worker isolation:

```ruby
# config/consts.rb automatically appends worker suffix to paths
# test_images → test_images-0, test_images-1, etc.

def test_upload_image
  # Just use normal image operations
  upload_image(fixture_file_upload("files/test.jpg"))
  # Automatically goes to correct worker-specific directory
end
```

**Setup**: Ensure worker-specific directories exist:
```bash
# In parallel_test.rake or setup scripts
for i in {0..7}; do
  mkdir -p public/test_images-$i/{thumb,320,640,960,1280,orig}
done
```

### 6. Configuration Files and IP Stats

**Problem**: Multiple workers writing to same config files.

**✅ Solution**: Use worker-specific paths in `config/consts.rb`:

```ruby
def config.blocked_ips_file
  if env == "test" && (worker_num = IMAGE_CONFIG_DATA.send(:database_worker_number))
    "#{root}/config/blocked_ips-#{worker_num}.txt"
  else
    "#{root}/config/blocked_ips.txt"
  end
end
```

This pattern is already implemented for:
- `blocked_ips.txt`
- `okay_ips.txt`
- `log/ip_stats.txt`

### 7. Language/Locale Files

**Problem**: Tests that export or modify locale files conflict.

**✅ Solution**: Use worker-specific locale directories:

```ruby
def test_export_locales
  # config/consts.rb automatically handles this
  # test_locales → test_locales-0, test_locales-1, etc.
  LanguageExporter.export_locales
  # Exports to worker-specific directory
end
```

### 8. Avoid `sleep()` for Synchronization

**❌ Bad - Race conditions**
```ruby
def test_async_operation
  start_background_job
  sleep(1)  # Hope it finishes in 1 second
  assert job_completed?
end
```

**✅ Good - Poll with timeout**
```ruby
def test_async_operation
  start_background_job

  timeout = 5.seconds.from_now
  until job_completed? || Time.current > timeout
    sleep(0.1)
  end

  assert job_completed?, "Job did not complete within 5 seconds"
end
```

### 9. Fixture Data Assumptions

**Problem**: Assuming specific database state that might be modified by other tests.

**❌ Bad - Relying on mutable state**
```ruby
def test_first_observation
  # Assumes observations.count stays constant
  assert_equal 50, Observation.count
end
```

**✅ Good - Use fixtures or create test data**
```ruby
def test_first_observation
  # Use fixture references
  obs = observations(:minimal_unknown_obs)
  assert obs.name.nil?

  # Or count relative to fixtures
  initial_count = Observation.count
  create_observation
  assert_equal initial_count + 1, Observation.count
end
```

## Best Practices Checklist

When writing new tests:

- [ ] Use `Tempfile.new("test").path` for temporary files
- [ ] Never hardcode paths like `/tmp/output.txt`
- [ ] Use thread-local storage (`Thread.current[:key]`) not class variables
- [ ] Clear thread-local storage in setup/teardown
- [ ] Include `GeneralExtensions` when using `database_worker_number`
- [ ] Pass `script_env` when calling bash scripts that query the database
- [ ] Don't assume specific counts or IDs in fixtures
- [ ] Use polling with timeouts instead of `sleep()` for async operations
- [ ] Let Rails/MO handle worker-specific paths for images, locales, IP stats

## Debugging Parallel Test Failures

### Symptoms of Parallel Issues

1. **Flaky tests**: Pass when run individually, fail in parallel
2. **File not found**: Worker trying to access another worker's files
3. **Wrong data**: Test sees data from different worker's database
4. **Deadlocks**: Multiple workers competing for same resource

### Debug Steps

1. **Run the test serially first**
   ```bash
   rails test test/path/to/flaky_test.rb:123
   ```

2. **Check for shared resources**
   - Hardcoded file paths?
   - Class variables instead of thread-local?
   - Shared cache or config files?

3. **Add logging to identify worker**
   ```ruby
   def test_flaky_test
     worker = database_worker_number || "serial"
     puts "Running in worker: #{worker}"
     # ...
   end
   ```

4. **Run with fewer workers to reduce race conditions**
   ```bash
   PARALLEL_WORKERS=2 rails test
   ```

5. **Check the actual database being used**
   ```ruby
   def test_debug_database
     db_name = ActiveRecord::Base.connection_db_config.configuration_hash[:database]
     puts "Using database: #{db_name}"
   end
   ```

## Testing the Parallel Setup

To verify parallel testing is working correctly:

```bash
# Run full test suite in parallel
PARALLEL_TEST_THRESHOLD=0 rails test

# Check that workers are isolated
rails test test/models/user_thread_safety_test.rb

# Verify bash scripts work
rails test test/classes/script_test.rb

# Verify image operations work
rails test test/classes/image_script_test.rb
```

## Infrastructure Files

Key files that support parallel testing:

- `test/test_helper.rb`: Configures parallel execution threshold
- `config/database.yml` / `db/vagrant/database.yml`: Database configuration with `MO_TEST_DATABASE` support for worker-specific databases
- `config/consts.rb`: Worker-specific path configuration
- `lib/extensions/general_extensions.rb`: `database_worker_number` helper
- `test/classes/script_test.rb`: `script_env` helper for passing worker config to bash/Ruby scripts
- `script/bash_include`: Bash script database configuration
- `test/support/parallel_test_helpers.rb`: Test utilities (if exists)

## Further Reading

- [Rails Parallel Testing Guide](https://guides.rubyonrails.org/testing.html#parallel-testing)
- [Minitest Parallel Execution](https://github.com/minitest/minitest#parallel-test-execution)
- Thread safety in Ruby: [Ruby Thread Documentation](https://ruby-doc.org/core/Thread.html)

## Questions or Issues?

If you encounter parallel testing issues:

1. Check this guide for similar patterns
2. Look for examples in `test/classes/script_test.rb` or `test/classes/image_script_test.rb`
3. Run the test serially to isolate the issue
4. Ask in team chat or open a GitHub issue with the test failure details
