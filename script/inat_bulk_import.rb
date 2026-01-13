#!/usr/bin/env ruby
# frozen_string_literal: true

# script/inat_bulk_import.rb
#
# Import iNaturalist observations from a text file using the existing
# controller/job infrastructure. Monitors progress and emails results.
#
# Usage:
#   rails r script/inat_bulk_import.rb <file_path> <username> [inat_username]
#
# File format (plain text, one ID per line, max 200 observations):
#   12345678
#   12345679
#   12345680
#
# Arguments:
#   file_path: Path to text file having iNat observation IDs (one per line)
#   mo_login: MO login of user who will perform the import
#   inat_username: Optional iNat username (defaults to MO user's inat_username)
#
# Example:
#   rails runner script/inat_bulk_import.rb inat_ids.txt joe mycologist123
#
# Note: This script will open a browser for OAuth authentication. You must
# complete the iNaturalist authorization flow before the import can proceed.

# Handles console output with timestamps
class ImportLogger
  def log(message)
    timestamp = Time.zone.now.strftime("%H:%M:%S")
    puts("[#{timestamp}] #{message}")
  end

  def log_error(message)
    timestamp = Time.zone.now.strftime("%H:%M:%S")
    warn("[#{timestamp}] ERROR: #{message}")
  end

  def log_section(title)
    log("\n#{"=" * 70}")
    log(title)
    log("=" * 70)
  end

  def log_separator
    log("=" * 70)
  end
end

# Validates prerequisites and loads observation IDs from file
class ImportFileLoader
  MAX_OBSERVATIONS = 200

  attr_reader :file_path, :logger

  def initialize(file_path, logger)
    @file_path = file_path
    @logger = logger
  end

  def validate_file_exists
    return if File.exist?(file_path)

    raise(ArgumentError.new("File not found: #{file_path}"))
  end

  def load_and_validate_ids
    ids = []

    File.foreach(file_path) do |line|
      id = line.strip
      next if id.blank? || id.start_with?("#")

      unless id.match?(/^\d+$/)
        logger.log("⚠ Skipping invalid ID: #{id}")
        next
      end

      ids << id
    end

    ids.uniq!
    validate_ids_count(ids)
    ids
  end

  private

  def validate_ids_count(ids)
    if ids.empty?
      logger.log("✗ No valid observation IDs found in file")
      return []
    end

    return unless ids.count > MAX_OBSERVATIONS

    raise(ArgumentError.new("Too many observations (#{ids.count}). " \
          "Maximum is #{MAX_OBSERVATIONS}. " \
          "Split your file into multiple files."))
  end
end

# Manages OAuth authorization flow
class ImportAuthorizationHandler
  attr_reader :logger

  def initialize(logger)
    @logger = logger
  end

  def ensure_api_key(user)
    key = find_or_create_api_key(user)
    verify_key(key) if key.verified.nil?
  end

  def trigger_oauth_flow(inat_import)
    log_authorization_instructions
    open_browser_for_authorization
    wait_for_authorization_callback(inat_import)
    logger.log("✓ Authorization received")
    logger.log("✓ Import job started")
  end

  private

  def find_or_create_api_key(user)
    key = APIKey.find_by(
      user: user,
      notes: Inat::Constants::MO_API_KEY_NOTES
    )

    return key unless key.nil?

    APIKey.create!(
      user: user,
      notes: Inat::Constants::MO_API_KEY_NOTES
    ).tap { logger.log("✓ Created API key") }
  end

  def verify_key(key)
    key.verify!
    logger.log("✓ Verified API key")
  end

  def log_authorization_instructions
    logger.log_section("OAUTH AUTHORIZATION REQUIRED")
    logger.log("Opening browser for iNaturalist authorization...")
    logger.log("Please complete the authorization in your browser.")
    logger.log("Waiting for authorization callback...")
    logger.log_separator
  end

  def open_browser_for_authorization
    authorization_url = Inat::Constants::INAT_AUTHORIZATION_URL

    if system("command -v open > /dev/null 2>&1")
      system("open '#{authorization_url}'")
    elsif system("command -v xdg-open > /dev/null 2>&1")
      system("xdg-open '#{authorization_url}'")
    else
      logger.log("Cannot open browser automatically. Please visit:")
      logger.log(authorization_url)
    end
  end

  def wait_for_authorization_callback(inat_import)
    timeout = 300 # 5 minutes
    elapsed = 0

    while inat_import.reload.state == "Authorizing"
      if elapsed >= timeout
        raise("Timeout waiting for OAuth authorization (#{timeout}s)")
      end

      sleep(5)
      elapsed += 5
      print(".")
    end

    puts # newline after dots
  end
end

# Monitors import job progress and reports status
class ImportProgressMonitor
  POLL_INTERVAL = 10 # seconds

  attr_reader :logger

  def initialize(logger)
    @logger = logger
  end

  def monitor(inat_import)
    log_monitoring_header
    track_progress(inat_import)
    logger.log("\n✓ Import job completed")
  end

  def wait_for_pending_job(inat_import)
    while inat_import.reload.job_pending?
      logger.log("  Still pending... (#{inat_import.state})")
      sleep(POLL_INTERVAL)
    end
    logger.log("  Previous job completed")
  end

  private

  def log_monitoring_header
    logger.log_section("MONITORING IMPORT PROGRESS")
    logger.log("Checking status every #{POLL_INTERVAL} seconds...")
    logger.log("Press Ctrl+C to stop monitoring (job will continue)")
    logger.log_separator
  end

  def track_progress(inat_import)
    last_state = nil
    last_count = 0

    loop do
      inat_import.reload
      current_state = inat_import.state
      current_count = inat_import.imported_count.to_i

      if state_changed?(last_state, current_state)
        log_state_change(last_state, current_state)
      end

      if count_changed?(current_count, last_count)
        log_progress_update(inat_import, current_count)
      end

      last_state = current_state
      last_count = current_count

      break if import_complete?(inat_import)

      sleep(POLL_INTERVAL)
    end
  end

  def state_changed?(last_state, current_state)
    current_state != last_state
  end

  def count_changed?(current_count, last_count)
    current_count != last_count
  end

  def log_state_change(last_state, current_state)
    logger.log("State changed: #{last_state} → #{current_state}")
  end

  def log_progress_update(inat_import, current_count)
    total = inat_import.importables || "?"
    percentage = calculate_percentage(inat_import, current_count)
    logger.log("Progress: #{current_count}/#{total} (#{percentage}%)")
  end

  def calculate_percentage(inat_import, current_count)
    return "?" unless inat_import.importables

    ratio = current_count.to_f / inat_import.importables
    (ratio * 100).round(1)
  end

  def import_complete?(inat_import)
    inat_import.state == "Done" || inat_import.canceled?
  end
end

# Handles email notification and completion summary
class ImportResultsReporter
  attr_reader :logger

  def initialize(logger)
    @logger = logger
  end

  def send_email(user, inat_import, batch_info)
    logger.log_section("SENDING RESULTS EMAIL")

    InatImportResultsMailer.build(
      user: user,
      inat_import: inat_import,
      batch_info: batch_info
    ).deliver_now

    logger.log("✓ Email sent to: #{user.email}")
  rescue StandardError => e
    log_email_error(e, inat_import)
  ensure
    logger.log_separator
  end

  # Cop disabled to avoid fragmenting the logic
  def log_completion_summary(inat_import) # rubocop:disable Metrics/AbcSize
    logger.log_section("IMPORT SUMMARY")
    logger.log("State: #{inat_import.state}")
    logger.log("Imported: #{inat_import.imported_count}")
    logger.log("Importable: #{inat_import.importables}")

    log_errors(inat_import)

    logger.log_separator
    timestamp = Time.zone.now.strftime("%Y-%m-%d %H:%M:%S %Z")
    logger.log("Completed at: #{timestamp}")
    logger.log_separator
  end

  private

  def log_email_error(error, inat_import)
    logger.log_error("✗ Failed to send email: #{error.message}")
    logger.log_error("Response errors:")
    return if inat_import.response_errors.blank?

    logger.log_error(inat_import.response_errors)
  end

  def log_errors(inat_import)
    if inat_import.response_errors.present?
      logger.log("\nERRORS:")
      logger.log("-" * 70)
      logger.log(inat_import.response_errors)
      logger.log("-" * 70)
    else
      logger.log("\n✓ No errors")
    end
  end
end

# Main orchestrator for bulk import process
class InatBulkImportRunner
  attr_reader :file_path, :mo_login, :inat_username, :batch_number
  attr_reader :logger, :file_loader, :auth_handler, :progress_monitor, :reporter

  def initialize(file_path, mo_login, inat_username = nil, batch_number = 1)
    @file_path = file_path
    @mo_login = mo_login
    @inat_username = inat_username
    @batch_number = batch_number
    @started_at = Time.zone.now

    @logger = ImportLogger.new
    @file_loader = ImportFileLoader.new(file_path, logger)
    @auth_handler = ImportAuthorizationHandler.new(logger)
    @progress_monitor = ImportProgressMonitor.new(logger)
    @reporter = ImportResultsReporter.new(logger)
  end

  # Cop disabled to avoid fragmenting the logic
  def run # rubocop:disable Metrics/AbcSize
    validate_prerequisites
    observation_ids = file_loader.load_and_validate_ids

    return if observation_ids.empty?

    log_batch_info(observation_ids)

    inat_import = prepare_import(observation_ids)
    trigger_import_job(inat_import)
    progress_monitor.monitor(inat_import)
    send_results_email(inat_import, observation_ids)

    reporter.log_completion_summary(inat_import)
  rescue StandardError => e
    logger.log_error("Fatal error: #{e.message}")
    logger.log_error(e.backtrace.join("\n"))
    raise
  end

  private

  # Cop disabled to avoid fragmenting the logic
  def validate_prerequisites # rubocop:disable Metrics/AbcSize
    file_loader.validate_file_exists
    raise(ArgumentError.new("User '#{mo_login}' not found")) unless user
    raise(ArgumentError.new("User has no email address")) if user.email.blank?

    logger.log("✓ User: #{user.login} (#{user.email})")
    logger.log("✓ User ID: #{user.id}")
    logger.log("✓ iNat username: #{effective_inat_username}")
  end

  def user
    return @user if defined?(@user)

    @user = User.find_by(login: mo_login)
  end

  def effective_inat_username
    @effective_inat_username ||=
      @inat_username || user.inat_username || user.login
  end

  # Cop disabled to avoid fragmenting the logic
  def log_batch_info(observation_ids) # rubocop:disable Metrics/AbcSize
    logger.log_section("iNaturalist Bulk Import")
    logger.log("Batch: ##{batch_number}")
    logger.log("File: #{file_path}")
    logger.log("MO User: #{user.login}")
    logger.log("iNat User: #{effective_inat_username}")
    logger.log("Observations: #{observation_ids.count}")
    logger.log("IDs: #{observation_ids.first}..#{observation_ids.last}")
    logger.log("Started: #{@started_at.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    logger.log_separator
  end

  # Cop disabled to avoid fragmenting the logic
  def prepare_import(observation_ids) # rubocop:disable Metrics/AbcSize
    inat_import = InatImport.find_or_create_by(user: user)

    if inat_import.job_pending?
      logger.log("⚠ User has a pending import job")
      logger.log("  Waiting for it to complete before starting new import...")
      progress_monitor.wait_for_pending_job(inat_import)
    end

    inat_import.update!(
      state: "Authorizing",
      import_all: false,
      importables: observation_ids.count,
      imported_count: 0,
      avg_import_time: inat_import.initial_avg_import_seconds,
      inat_ids: observation_ids.join(","),
      inat_username: effective_inat_username,
      response_errors: "",
      token: "",
      log: ["Bulk import batch #{batch_number} from #{file_path}"],
      ended_at: nil,
      cancel: false
    )

    logger.log("✓ Prepared InatImport record ##{inat_import.id}")
    inat_import
  end

  def trigger_import_job(inat_import)
    auth_handler.ensure_api_key(user)
    auth_handler.trigger_oauth_flow(inat_import)
  end

  def send_results_email(inat_import, observation_ids)
    batch_info = build_batch_info(observation_ids)
    reporter.send_email(user, inat_import, batch_info)
  end

  def build_batch_info(observation_ids)
    completed_at = Time.zone.now
    duration_minutes = ((completed_at - @started_at) / 60.0).round(2)

    {
      batch_number: batch_number,
      file_path: file_path,
      started_at: @started_at,
      completed_at: completed_at,
      duration_minutes: duration_minutes,
      total_ids: observation_ids.count
    }
  end
end

# Script entry point
if __FILE__ == $PROGRAM_NAME
  if ARGV.length < 2
    puts("Usage: rails runner #{__FILE__} <file_path> <mo_login> " \
         "[inat_username]")
    puts("")
    puts("Arguments:")
    puts("  file_path:      Path to text file " \
         "(one iNat observation ID per line)")
    puts("  mo_login:       MO username who will perform the import")
    puts("  inat_username:  Optional iNat username " \
         "(defaults to user's inat_username)")
    puts("")
    puts("Example:")
    puts("  rails runner #{__FILE__} inat_ids.txt joe mycologist123")
    puts("")
    puts("Note: Maximum #{ImportFileLoader::MAX_OBSERVATIONS} " \
         "observations per batch.")
    puts("      OAuth browser authorization required.")
    exit(1)
  end

  file_path = ARGV[0]
  mo_login = ARGV[1]
  inat_username = ARGV[2]

  runner = InatBulkImportRunner.new(file_path, mo_login, inat_username)
  runner.run
end
