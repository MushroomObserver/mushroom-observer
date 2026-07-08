# frozen_string_literal: true

# Nightly clean-up: runs a batch of idempotent "make sure X is correct"
# repair methods across several models. See each method's own
# documentation for details of what it fixes.
#
# `Name.propagate_generic_classifications` is deliberately left out — it's
# a complex operation that wants to make thousands of changes to the
# database and hasn't been vetted enough to run unattended yet.
class RefreshCachesJob < ApplicationJob
  queue_as :maintenance

  TASKS = [
    [Synonym, :make_sure_all_referenced_synonyms_exist,
     "unused or missing synonyms"],
    [Name, :fix_self_referential_misspellings,
     "self-referential misspellings"],
    [Name, :make_sure_names_are_bolded_correctly, "misformatted names"],
    [Observation, :make_sure_no_observations_are_misspelled,
     "misspelled observations"],
    [Observation, :refresh_content_filter_caches, "content filter caches"],
    [Occurrence, :refresh_has_specimen_cache,
     "occurrence has_specimen cache"],
    [Observation, :refresh_needs_naming_column,
     "observations needing naming"],
    [Vote, :update_observation_views_reviewed_column,
     "observations reviewed"],
    [User, :cull_unverified_users, "cull unverified users"],
    [UserStats, :refresh_all_user_stats, "update user_stats"]
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
