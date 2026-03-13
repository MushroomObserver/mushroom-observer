# frozen_string_literal: true

# Service for managing parallel test MySQL configuration files
class ParallelTestConfigService
  attr_reader :output_handler, :rails_root

  def initialize(
    output_handler: ParallelTestConfigService::StdoutOutputHandler.new,
    rails_root: Rails.root
  )
    @output_handler = output_handler
    @rails_root = rails_root
  end

  # Generate MySQL config files for parallel testing
  # @return [Boolean] true if successful, false otherwise
  def setup_config_files
    workers = worker_count
    output_handler.puts(
      "Setting up parallel test configuration for #{workers} workers..."
    )

    credentials = database_credentials
    return false unless credentials

    generate_config_files(workers, credentials)
    display_setup_complete
    true
  rescue StandardError => e
    output_handler.puts("ERROR: #{e.message}")
    false
  end

  # Remove MySQL config files for parallel testing
  # @return [Boolean] true if successful, false otherwise
  def cleanup_config_files
    config_files = find_config_files

    if config_files.empty?
      output_handler.puts("No parallel test config files to clean up.")
    else
      remove_config_files(config_files)
      output_handler.puts("\nCleaned up #{config_files.size} config file(s).")
    end
    true
  rescue StandardError => e
    output_handler.puts("ERROR: #{e.message}")
    false
  end

  private

  def worker_count
    ENV.fetch("PARALLEL_WORKERS", Etc.nprocessors).to_i
  end

  def database_credentials
    config_path = rails_root.join("config/database.yml")

    unless File.exist?(config_path)
      output_handler.puts(
        "ERROR: config/database.yml not found. " \
        "Please copy from db/macos/database.yml or " \
        "db/vagrant/database.yml"
      )
      return nil
    end

    database_config = YAML.load_file(config_path)
    test_config = database_config["test"]

    unless test_config
      output_handler.puts(
        "ERROR: 'test' configuration not found in config/database.yml"
      )
      return nil
    end

    {
      username: test_config["username"] || "mo",
      password: test_config["password"] || "mo"
    }
  end

  def generate_config_files(workers, credentials)
    workers.times do |worker_num|
      create_worker_config_file(worker_num, credentials)
    end
  end

  def create_worker_config_file(worker_num, credentials)
    config_path = rails_root.join("config/mysql-test-#{worker_num}.cnf")
    database_name = "mo_test-#{worker_num}"

    # Security note: MySQL config files require plain-text passwords by design.
    # This is acceptable because:
    # 1. These are test-only credentials for local development
    # 2. Files are in .gitignore and never committed
    # 3. Only used for parallel test execution
    # 4. Cleaned up after tests complete
    File.write(config_path, mysql_config_content(
                              database_name,
                              credentials[:username],
                              credentials[:password]
                            ))

    output_handler.puts("  Created #{config_path}")
  end

  def mysql_config_content(database, username, password)
    <<~MYSQL_CONFIG
      [client]
      user=#{username}
      password=#{password}

      [mysql]
      database=#{database}
    MYSQL_CONFIG
  end

  def find_config_files
    config_dir = rails_root.join("config")
    Dir.glob(config_dir.join("mysql-test-*.cnf"))
  end

  def remove_config_files(config_files)
    config_files.each do |file|
      File.delete(file)
      output_handler.puts("  Deleted #{file}")
    end
  end

  def display_setup_complete
    output_handler.puts("\nParallel test setup complete!")
    output_handler.puts("\nTo run tests in parallel, use:")
    output_handler.puts("  rails test")
    output_handler.puts("\nTo force parallel testing even for small files:")
    output_handler.puts("  PARALLEL_TEST_THRESHOLD=0 rails test")
  end
end
