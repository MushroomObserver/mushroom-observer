# frozen_string_literal: true

require("test_helper")

class ParallelTestConfigServiceTest < UnitTestCase
  def setup
    @output = StringIO.new
    @output_handler = MockOutputHandler.new(@output)
    @temp_dir = Dir.mktmpdir
    @rails_root = Pathname.new(@temp_dir)
    @service = ParallelTestConfigService.new(
      output_handler: @output_handler,
      rails_root: @rails_root
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  # Helper to create a valid database.yml file
  def create_database_yml(test_config = nil)
    test_config ||= {
      "username" => "test_user",
      "password" => "test_pass"
    }

    config = { "test" => test_config }
    config_path = @rails_root.join("config")
    FileUtils.mkdir_p(config_path)
    File.write(config_path.join("database.yml"), YAML.dump(config))
  end

  # Helper to get output messages
  def output_messages
    @output.string
  end

  # Test: Successfully set up config files with default worker count
  def test_setup_config_files_success
    create_database_yml
    worker_count = Etc.nprocessors

    result = @service.setup_config_files

    assert(result, "setup_config_files should return true")
    assert_match(/Setting up parallel test configuration for #{worker_count}/,
                 output_messages)
    assert_match(/Parallel test setup complete!/, output_messages)

    # Verify config files were created
    worker_count.times do |i|
      config_file = @rails_root.join("config/mysql-test-#{i}.cnf")
      assert(File.exist?(config_file), "Config file #{i} should exist")

      content = File.read(config_file)
      assert_match(/user=test_user/, content)
      assert_match(/password=test_pass/, content)
      assert_match(/database=mo_test-#{i}/, content)
    end
  end

  # Test: Set up config files with custom worker count
  def test_setup_config_files_custom_worker_count
    create_database_yml
    worker_count = 3

    ENV["PARALLEL_WORKERS"] = worker_count.to_s
    begin
      result = @service.setup_config_files

      assert(result, "setup_config_files should return true")
      assert_match(/Setting up parallel test configuration for #{worker_count}/,
                   output_messages)

      # Verify only 3 config files were created
      worker_count.times do |i|
        config_file = @rails_root.join("config/mysql-test-#{i}.cnf")
        assert(File.exist?(config_file), "Config file #{i} should exist")
      end

      # Verify no extra files
      assert_not(File.exist?(@rails_root.join("config/mysql-test-3.cnf")),
                 "Should not create extra config files")
    ensure
      ENV.delete("PARALLEL_WORKERS")
    end
  end

  # Test: Set up config files with default credentials when not specified
  def test_setup_config_files_default_credentials
    create_database_yml({})

    result = @service.setup_config_files

    assert(result, "setup_config_files should return true")

    # Check first config file has default credentials
    config_file = @rails_root.join("config/mysql-test-0.cnf")
    content = File.read(config_file)
    assert_match(/user=mo/, content)
    assert_match(/password=mo/, content)
  end

  # Test: Fail when database.yml is missing
  def test_setup_config_files_missing_database_yml
    result = @service.setup_config_files

    assert_not(result, "setup_config_files should return false")
    assert_match(%r{ERROR: config/database.yml not found}, output_messages)
    assert_match(%r{Please copy from db/macos/database.yml},
                 output_messages)
  end

  # Test: Fail when test configuration is missing from database.yml
  def test_setup_config_files_missing_test_config
    config_path = @rails_root.join("config")
    FileUtils.mkdir_p(config_path)
    File.write(config_path.join("database.yml"),
               YAML.dump({ "development" => {} }))

    result = @service.setup_config_files

    assert_not(result, "setup_config_files should return false")
    assert_match(/ERROR: 'test' configuration not found/, output_messages)
  end

  # Test: Handle file write errors gracefully
  def test_setup_config_files_write_error
    create_database_yml

    # Make config directory read-only to cause write failure
    config_path = @rails_root.join("config")
    FileUtils.chmod(0o444, config_path)

    begin
      result = @service.setup_config_files

      assert_not(result,
                 "setup_config_files should return false on write error")
      assert_match(/ERROR:/, output_messages)
    ensure
      FileUtils.chmod(0o755, config_path)
    end
  end

  # Test: Successfully clean up config files
  def test_cleanup_config_files_success
    # Create some test config files
    config_path = @rails_root.join("config")
    FileUtils.mkdir_p(config_path)

    3.times do |i|
      File.write(config_path.join("mysql-test-#{i}.cnf"), "test content")
    end

    result = @service.cleanup_config_files

    assert(result, "cleanup_config_files should return true")
    assert_match(/Deleted.*mysql-test-0.cnf/, output_messages)
    assert_match(/Deleted.*mysql-test-1.cnf/, output_messages)
    assert_match(/Deleted.*mysql-test-2.cnf/, output_messages)
    assert_match(/Cleaned up 3 config file/, output_messages)

    # Verify files were deleted
    3.times do |i|
      assert_not(File.exist?(config_path.join("mysql-test-#{i}.cnf")),
                 "Config file #{i} should be deleted")
    end
  end

  # Test: Cleanup when no config files exist
  def test_cleanup_config_files_none_exist
    config_path = @rails_root.join("config")
    FileUtils.mkdir_p(config_path)

    result = @service.cleanup_config_files

    assert(result, "cleanup_config_files should return true")
    assert_match(/No parallel test config files to clean up/, output_messages)
  end

  # Test: Handle cleanup errors gracefully
  def test_cleanup_config_files_delete_error
    config_path = @rails_root.join("config")
    FileUtils.mkdir_p(config_path)
    File.write(config_path.join("mysql-test-0.cnf"), "test")

    # Stub File.delete to raise an error
    error = StandardError.new("Delete failed")
    File.stub(:delete, ->(_path) { raise(error) }) do
      result = @service.cleanup_config_files

      assert_not(result, "cleanup_config_files should return false on error")
      assert_match(/ERROR: Delete failed/, output_messages)
    end
  end

  # Test: Config file content format is correct
  def test_config_file_format
    create_database_yml({
                          "username" => "custom_user",
                          "password" => "custom_pass"
                        })

    ENV["PARALLEL_WORKERS"] = "1"
    begin
      @service.setup_config_files

      config_file = @rails_root.join("config/mysql-test-0.cnf")
      content = File.read(config_file)

      # Verify sections
      assert_match(/\[client\]/, content)
      assert_match(/\[mysql\]/, content)

      # Verify credentials
      assert_match(/^user=custom_user$/, content)
      assert_match(/^password=custom_pass$/, content)

      # Verify database
      assert_match(/^database=mo_test-0$/, content)

      # Verify proper format (no extra whitespace, proper line breaks)
      lines = content.lines
      assert_equal("[client]\n", lines[0])
      assert_equal("user=custom_user\n", lines[1])
      assert_equal("password=custom_pass\n", lines[2])
      assert_equal("\n", lines[3])
      assert_equal("[mysql]\n", lines[4])
      assert_equal("database=mo_test-0\n", lines[5])
    ensure
      ENV.delete("PARALLEL_WORKERS")
    end
  end

  # Test: Setup displays helpful instructions
  def test_setup_displays_instructions
    create_database_yml

    ENV["PARALLEL_WORKERS"] = "2"
    begin
      @service.setup_config_files

      output = output_messages
      assert_match(/To run tests in parallel, use:/, output)
      assert_match(/rails test/, output)
      assert_match(/To force parallel testing even for small files:/, output)
      assert_match(/PARALLEL_TEST_THRESHOLD=0 rails test/, output)
    ensure
      ENV.delete("PARALLEL_WORKERS")
    end
  end

  # Test: Cleanup only removes mysql-test-*.cnf files
  def test_cleanup_only_removes_parallel_test_configs
    config_path = @rails_root.join("config")
    FileUtils.mkdir_p(config_path)

    # Create parallel test config files
    File.write(config_path.join("mysql-test-0.cnf"), "test")
    # Create other config file that should not be deleted
    File.write(config_path.join("mysql-production.cnf"), "production")
    File.write(config_path.join("other.txt"), "other")

    @service.cleanup_config_files

    # Verify only parallel test configs were deleted
    assert_not(File.exist?(config_path.join("mysql-test-0.cnf")))
    assert(File.exist?(config_path.join("mysql-production.cnf")),
           "Should not delete non-test config files")
    assert(File.exist?(config_path.join("other.txt")),
           "Should not delete other files")
  end
end

# Mock output handler for testing
class MockOutputHandler
  delegate :puts, :print, to: :@output

  def initialize(output)
    @output = output
  end
end
