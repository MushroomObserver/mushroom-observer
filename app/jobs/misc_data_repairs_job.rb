# frozen_string_literal: true

# Nightly clean-up: runs a batch of idempotent "make sure X is correct"
# repair methods across several models. See each method's own
# documentation for details of what it fixes. Named for what's left
# after the split below, not "RefreshCachesJob" -- that name implied
# it still ran the full original set, and half of what's left here
# (misspelling fixes, culling unverified users) was never a cache
# refresh to begin with.
#
# `Name.propagate_generic_classifications` is deliberately left out — it's
# a complex operation that wants to make thousands of changes to the
# database and hasn't been vetted enough to run unattended yet.
#
# The three tasks that dominated this job's runtime (measured locally
# against a recent production-size DB copy: UserStats ~9s, Observation
# content-filter caches ~6.6s, Vote's observation-views repair ~4.8s,
# vs. well under 2s each for everything below) were split out into
# their own jobs -- RefreshAllUserStatsJob, RefreshContentFilterCachesJob,
# UpdateObservationViewsReviewedColumnJob -- so each can be staggered
# independently and none of the cheap tasks here has to wait behind
# whichever of the three is having a slow night.
class MiscDataRepairsJob < ApplicationJob
  queue_as :maintenance

  TASKS = [
    [Synonym, :make_sure_all_referenced_synonyms_exist,
     "unused or missing synonyms"],
    [Name, :fix_self_referential_misspellings,
     "self-referential misspellings"],
    [Name, :make_sure_names_are_bolded_correctly, "misformatted names"],
    [Observation, :make_sure_no_observations_are_misspelled,
     "misspelled observations"],
    [Occurrence, :refresh_has_specimen_cache,
     "occurrence has_specimen cache"],
    [Observation, :refresh_needs_naming_column,
     "observations needing naming"],
    [User, :cull_unverified_users, "cull unverified users"]
  ].freeze

  def perform(dry_run: false)
    msgs = TASKS.flat_map do |klass, method, desc|
      run_task(klass, method, desc, dry_run)
    end
    log(msgs.join("\n")) if msgs.any?
  end

  private

  def run_task(klass, method, description, dry_run)
    log("#{description}...")
    klass.send(method, dry_run: dry_run)
  end
end
