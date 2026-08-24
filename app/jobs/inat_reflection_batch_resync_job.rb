# frozen_string_literal: true

# Daily scheduled refresh of every read-only reflection due for sync from
# its iNaturalist source (#4215). Runs on the :maintenance queue like the
# other daily housekeeping jobs; the work is a handful of rate-limited
# iNat API calls, so it belongs in the background, not a request. Sync is
# owned by the admin account -- see Inat::ReflectionResync -- so no
# triggering user is carried. See config/recurring.yml for the schedule.
class InatReflectionBatchResyncJob < ApplicationJob
  queue_as :maintenance

  def perform
    counts = Inat::ReflectionBatchResyncer.new.resync_all
    Rails.logger.info("InatReflectionBatchResyncJob: #{counts.inspect}")
  end
end
