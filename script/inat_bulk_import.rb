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

class InatBulkImportRunner
  MAX_OBSERVATIONS = 200
  POLL_INTERVAL = 10 # seconds

  attr_reader :file_path, :mo_login, :inat_username, :batch_number

  def initialize(file_path, mo_login, inat_username = nil, batch_number = 1)
    @file_path = file_path
    @mo_login = mo_login
    @inat_username = inat_username
    @batch_number = batch_number
    @started_at = Time.zone.now
  end

  def run
    validate_prerequisites
    observation_ids = load_and_validate_ids

    return if observation_ids.empty?

    log_batch_info(observation_ids)

    inat_import = prepare_import(observation_ids)
    trigger_import_job(inat_import)
    monitor_import_progress(inat_import)
    send_results_email(inat_import, observation_ids)

    log_completion(inat_import)
  rescue StandardError => e
    log_error("Fatal error: #{e.message}")
    log_error(e.backtrace.join("\n"))
    raise
  end

  private

  def validate_prerequisites
    unless File.exist?(file_path)
      raise(ArgumentError.new("File not found: #{file_path}"))
    end
    raise(ArgumentError.new("User '#{mo_login}' not found")) unless user
    raise(ArgumentError.new("User has no email address")) if user.email.blank?

    log("✓ User: #{user.login} (#{user.email})")
    log("✓ User ID: #{user.id}")
    log("✓ iNat username: #{effective_inat_username}")
  end

  def user
    return @user if defined?(@user)

    @user = User.find_by(login: mo_login)
  end

  def effective_inat_username
    @effective_inat_username ||=
      @inat_username || user.inat_username || user.login
  end

  def load_and_validate_ids
    ids = []

    File.foreach(file_path) do |line|
      id = line.strip
      next if id.blank? || id.start_with?("#")

      unless id.match?(/^\d+$/)
        log("⚠ Skipping invalid ID: #{id}")
        next
      end

      ids << id
    end

    ids.uniq!

    if ids.empty?
      log("✗ No valid observation IDs found in file")
      return []
    end

    if ids.count > MAX_OBSERVATIONS
      raise(ArgumentError,
            "Too many observations (#{ids.count}). " \
            "Maximum is #{MAX_OBSERVATIONS}. " \
            "Split your file into multiple files.")
    end

    ids
  end

  def log_batch_info(observation_ids)
    log("\n" + "=" * 70)
    log("iNaturalist Bulk Import")
    log("=" * 70)
    log("Batch: ##{batch_number}")
    log("File: #{file_path}")
    log("MO User: #{user.login}")
    log("iNat User: #{effective_inat_username}")
    log("Observations: #{observation_ids.count}")
    log("IDs: #{observation_ids.first}..#{observation_ids.last}")
    log("Started: #{@started_at.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    log("=" * 70 + "\n")
  end

  def prepare_import(observation_ids)
    inat_import = InatImport.find_or_create_by(user: user)

    if inat_import.job_pending?
      log("⚠ User has a pending import job")
      log("  Waiting for it to complete before starting new import...")
      wait_for_job_completion(inat_import)
    end

    # Prepare the import record (mimics controller's init_ivars)
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

    log("✓ Prepared InatImport record ##{inat_import.id}")
    inat_import
  end

  def trigger_import_job(inat_import)
    # Ensure user has API key
    # (mimics controller's assure_user_has_inat_import_api_key)
    ensure_api_key

    log("\n" + "=" * 70)
    log("OAUTH AUTHORIZATION REQUIRED")
    log("=" * 70)
    log("Opening browser for iNaturalist authorization...")
    log("Please complete the authorization in your browser.")
    log("Waiting for authorization callback...")
    log("=" * 70 + "\n")

    # Open browser for OAuth authorization
    # Note: This requires the MO server to be running to receive the callback
    authorization_url = Inat::Constants::INAT_AUTHORIZATION_URL

    if system("command -v open > /dev/null 2>&1")
      system("open '#{authorization_url}'")
    elsif system("command -v xdg-open > /dev/null 2>&1")
      system("xdg-open '#{authorization_url}'")
    else
      log("Cannot open browser automatically. Please visit:")
      log(authorization_url)
    end

    # Wait for authorization callback to update the inat_import record
    wait_for_authorization(inat_import)

    log("✓ Authorization received")
    log("✓ Import job started")
  end

  def ensure_api_key
    key = APIKey.find_by(
      user: user,
      notes: Inat::Constants::MO_API_KEY_NOTES
    )

    if key.nil?
      key = APIKey.create!(
        user: user,
        notes: Inat::Constants::MO_API_KEY_NOTES
      )
      log("✓ Created API key")
    end

    return unless key.verified.nil?

    key.verify!
    log("✓ Verified API key")
  end

  def wait_for_authorization(inat_import)
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

  def monitor_import_progress(inat_import)
    log("\n" + "=" * 70)
    log("MONITORING IMPORT PROGRESS")
    log("=" * 70)
    log("Checking status every #{POLL_INTERVAL} seconds...")
    log("Press Ctrl+C to stop monitoring (job will continue)")
    log("=" * 70 + "\n")

    last_state = nil
    last_count = 0

    loop do
      inat_import.reload

      current_state = inat_import.state
      current_count = inat_import.imported_count.to_i

      # Log state changes
      if current_state != last_state
        log("State changed: #{last_state} → #{current_state}")
        last_state = current_state
      end

      # Log progress updates
      if current_count != last_count
        total = inat_import.importables || "?"
        percentage = inat_import.importables ?
                     (current_count.to_f / inat_import.importables * 100).round(1) :
                     "?"
        log("Progress: #{current_count}/#{total} (#{percentage}%)")
        last_count = current_count
      end

      # Check if done
      break if current_state == "Done"

      # Check if canceled
      if inat_import.canceled?
        log("⚠ Import was canceled")
        break
      end

      sleep(POLL_INTERVAL)
    end

    log("\n✓ Import job completed")
  end

  def wait_for_job_completion(inat_import)
    while inat_import.reload.job_pending?
      log("  Still pending... (#{inat_import.state})")
      sleep(POLL_INTERVAL)
    end
    log("  Previous job completed")
  end

  def send_results_email(inat_import, observation_ids)
    log("\n" + "=" * 70)
    log("SENDING RESULTS EMAIL")
    log("=" * 70)

    completed_at = Time.zone.now
    duration_minutes = ((completed_at - @started_at) / 60.0).round(2)

    batch_info = {
      batch_number: batch_number,
      file_path: file_path,
      started_at: @started_at,
      completed_at: completed_at,
      duration_minutes: duration_minutes,
      total_ids: observation_ids.count
    }

    begin
      InatImportResultsMailer.build(
        user: user,
        inat_import: inat_import,
        batch_info: batch_info
      ).deliver_now

      log("✓ Email sent to: #{user.email}")
    rescue StandardError => e
      log_error("✗ Failed to send email: #{e.message}")
      log_error("Response errors:")
      return if inat_import.response_errors.blank?

      log_error(inat_import.response_errors)
    end

    log("=" * 70)
  end

  def log_completion(inat_import)
    log("\n" + "=" * 70)
    log("IMPORT SUMMARY")
    log("=" * 70)
    log("State: #{inat_import.state}")
    log("Imported: #{inat_import.imported_count}")
    log("Importable: #{inat_import.importables}")

    if inat_import.response_errors.present?
      log("\nERRORS:")
      log("-" * 70)
      log(inat_import.response_errors)
      log("-" * 70)
    else
      log("\n✓ No errors")
    end

    log("=" * 70)
    log("Completed at: #{Time.zone.now.strftime("%Y-%m-%d %H:%M:%S %Z")}")
    log("=" * 70 + "\n")
  end

  def log(message)
    timestamp = Time.zone.now.strftime("%H:%M:%S")
    puts("[#{timestamp}] #{message}")
  end

  def log_error(message)
    timestamp = Time.zone.now.strftime("%H:%M:%S")
    warn("[#{timestamp}] ERROR: #{message}")
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
    puts("Note: Maximum #{InatBulkImportRunner::MAX_OBSERVATIONS} " \
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
