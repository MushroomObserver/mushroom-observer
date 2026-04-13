# frozen_string_literal: true

# Finds InatImport records stuck in the Importing state and marks them Done.
# Scheduled in config/recurring.yml to run every STUCK_THRESHOLD minutes.
# This recovers from worker process crashes (e.g., SIGKILL, OOM) where the
# job's ensure block never ran.
class InatImportRecoveryJob < ApplicationJob
  queue_as :default

  def perform
    InatImport.where(state: "Importing", ended_at: nil).
      where(updated_at: ..InatImport::STUCK_THRESHOLD.ago).
      find_each do |import|
        import.update(state: "Done", ended_at: Time.zone.now)
        import.add_response_error(
          "Import did not complete — the import may have crashed. " \
          "You can restart the import."
        )
        Rails.logger.warn(
          "InatImportRecoveryJob: marked stuck import #{import.id} as Done"
        )
      end
  end
end
