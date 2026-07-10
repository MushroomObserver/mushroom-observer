# frozen_string_literal: true

# Nightly clean-up: recomputes every user's cached UserStats columns.
# Split out of MiscDataRepairsJob (then still named RefreshCachesJob)
# -- this was its single heaviest task
# (measured locally against a recent production-size DB copy: ~9s of
# a ~25s total, and further ahead of the pack on production's larger
# scale), so it gets its own schedule slot instead of making every
# other (much cheaper) task in that job wait behind it.
class RefreshAllUserStatsJob < ApplicationJob
  queue_as :maintenance

  def perform(dry_run: false)
    msgs = UserStats.refresh_all_user_stats(dry_run: dry_run)
    log(msgs.join("\n")) if msgs.any?
  end
end
