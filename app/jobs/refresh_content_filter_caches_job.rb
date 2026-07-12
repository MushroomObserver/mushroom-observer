# frozen_string_literal: true

# Nightly clean-up: refreshes Observation's cached content-filter
# columns. Split out of MiscDataRepairsJob (then still named
# RefreshCachesJob) -- this was its second-heaviest task (measured
# locally against a recent production-size DB copy: ~6.6s of a ~25s
# total), so it gets its own schedule slot instead of making every
# other (much cheaper) task in that job wait behind it.
class RefreshContentFilterCachesJob < ApplicationJob
  queue_as :maintenance

  def perform(dry_run: false)
    msgs = Observation.refresh_content_filter_caches(dry_run: dry_run)
    log(msgs.join("\n")) if msgs.any?
  end
end
