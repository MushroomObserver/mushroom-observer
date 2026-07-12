# frozen_string_literal: true

# Nightly clean-up: reconciles ObservationView's `reviewed` column
# against the Vote rows it should track. Split out of MiscDataRepairsJob
# (then still named RefreshCachesJob) -- this was its third-heaviest
# task (measured locally against a recent production-size DB copy:
# ~4.8s of a ~25s total), and the one
# most likely to get slower as data grows: its "missing views" half
# (Vote.add_missing_views_corresponding_to_votes) creates one
# ObservationView row at a time rather than in bulk. Gets its own
# schedule slot instead of making every other (much cheaper) task in
# that job wait behind it.
class UpdateObservationViewsReviewedColumnJob < ApplicationJob
  queue_as :maintenance

  def perform(dry_run: false)
    msgs = Vote.update_observation_views_reviewed_column(dry_run: dry_run)
    log(msgs.join("\n")) if msgs.any?
  end
end
