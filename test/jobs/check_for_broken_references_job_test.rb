# frozen_string_literal: true

require("test_helper")

class CheckForBrokenReferencesJobTest < ActiveJob::TestCase
  DANGLING_ID = 999_999_999

  def test_delete_action_removes_dangling_row
    key = api_keys(:rolfs_api_key)
    key.update_column(:user_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_not(APIKey.exists?(key.id))
  end

  def test_nil_action_nulls_dangling_column
    list = species_lists(:first_species_list)
    list.update_column(:location_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_nil(list.reload.location_id)
  end

  def test_zero_action_zeroes_dangling_column
    article = articles(:premier_article)
    article.update_column(:user_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_equal(0, article.reload.user_id)
  end

  def test_alert_action_only_reports_does_not_modify
    coll_num = collection_numbers(:minimal_unknown_coll_num)
    coll_num.update_column(:user_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_equal(DANGLING_ID, coll_num.reload.user_id,
                 ":alert should report, not modify, the dangling reference")
  end

  def test_polymorphic_action_deletes_dangling_row
    interest = interests(:detailed_unknown_obs_interest)
    interest.update_column(:target_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now

    assert_not(Interest.exists?(interest.id))
  end

  # Regression coverage for a real gap the introspection-based derivation
  # found and fixed: ExternalLink#target has allowed an Image since #4299/
  # #4529 (Image declares `has_many :external_links, as: :target`), but the
  # old hand-maintained POLYMORPHIC list only ever paired
  # [ExternalLink, Observation] - an ExternalLink dangling off a deleted
  # Image was silently never checked.
  def test_polymorphic_action_covers_image_target
    image = images(:in_situ_image)
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    link.update_columns(target_type: "Image", target_id: image.id)

    CheckForBrokenReferencesJob.perform_now
    assert(ExternalLink.exists?(link.id), "sanity: valid target survives")

    link.update_column(:target_id, DANGLING_ID)
    CheckForBrokenReferencesJob.perform_now

    assert_not(ExternalLink.exists?(link.id))
  end

  # Same class of gap as above, for Interest#target -> LocationDescription
  # and Interest#target -> NameDescription (both real `has_many ...,
  # as: :target` declarations the old hand list never paired).
  def test_polymorphic_action_covers_location_description_and_name_description
    loc_desc = location_descriptions(:albion_desc)
    name_desc = name_descriptions(:agaricus_campestras_desc)
    loc_interest = interests(:detailed_unknown_obs_interest)
    name_interest = interests(:agaricus_campestros_interest)
    loc_interest.update_columns(target_type: "LocationDescription",
                                target_id: loc_desc.id)
    name_interest.update_columns(target_type: "NameDescription",
                                 target_id: name_desc.id)

    loc_interest.update_column(:target_id, DANGLING_ID)
    name_interest.update_column(:target_id, DANGLING_ID)
    CheckForBrokenReferencesJob.perform_now

    assert_not(Interest.exists?(loc_interest.id))
    assert_not(Interest.exists?(name_interest.id))
  end

  def test_dry_run_reports_without_modifying
    key = api_keys(:rolfs_api_key)
    key.update_column(:user_id, DANGLING_ID)

    CheckForBrokenReferencesJob.perform_now(dry_run: true)

    assert(APIKey.exists?(key.id),
           "dry_run should not delete the dangling row")
  end

  def test_invalid_action_raises
    job = CheckForBrokenReferencesJob.new
    job.instance_variable_set(:@dry_run, true)

    assert_raises(RuntimeError) do
      job.send(:apply_action, APIKey, :user_id, APIKey.none, [1],
               :bogus_action)
    end
  end

  def test_perform_runs_end_to_end_without_error
    CheckForBrokenReferencesJob.perform_now(verbose: true)
  end

  # A dangling :alert reference produces exactly one summary alert for the
  # whole run, naming the offending table.column.
  def test_emits_one_review_alert_for_dangling_alert_reference
    coll_num = collection_numbers(:minimal_unknown_coll_num)
    coll_num.update_column(:user_id, DANGLING_ID)

    alerts = capture_alerts { CheckForBrokenReferencesJob.perform_now }

    assert_equal(1, alerts.size, "expected exactly one summary alert per run")
    assert_instance_of(JobAlert, alerts.first)
    assert_includes(alerts.first.message, "collection_numbers.user_id")
  end

  # emit_review_summary is the "at most one alert per run" choke point:
  # nothing to review => no alert, so a quiet week stays silent.
  def test_no_alert_when_run_finds_nothing_to_review
    job = CheckForBrokenReferencesJob.new
    job.instance_variable_set(:@review_findings, [])

    alerts = capture_alerts { job.send(:emit_review_summary) }

    assert_empty(alerts, "a run with no findings should emit no alert")
  end

  # Multiple findings in one run collapse into a single summary alert.
  def test_multiple_findings_collapse_into_one_summary_alert
    job = CheckForBrokenReferencesJob.new
    job.instance_variable_set(:@review_findings,
                              ["dangling foo.bar",
                               "STALE ACTIONS ENTRY: Baz.qux"])

    alerts = capture_alerts { job.send(:emit_review_summary) }

    assert_equal(1, alerts.size)
    assert_includes(alerts.first.message, "2 reference issue")
    assert_includes(alerts.first.message, "dangling foo.bar")
    assert_includes(alerts.first.message, "STALE ACTIONS ENTRY: Baz.qux")
  end

  # An ACTIONS entry naming an association that no longer exists (renamed/
  # removed/turned polymorphic) is logged AND flagged for the #alerts
  # summary, instead of silently rotting or crashing the run.
  def test_stale_actions_entry_is_logged_and_flagged_for_review
    job = CheckForBrokenReferencesJob.new
    logged = []
    job.define_singleton_method(:log) { |msg| logged << msg }
    job.instance_variable_set(:@review_findings, [])

    CheckForBrokenReferencesJob::Checks.stub(:stale_action_entries,
                                             ["Foo.bar"]) do
      job.send(:report_stale_action_entries)
    end

    assert_includes(logged.first, "STALE ACTIONS ENTRY: Foo.bar")
    assert_includes(job.instance_variable_get(:@review_findings).first,
                    "STALE ACTIONS ENTRY: Foo.bar")
  end

  # A real association with no considered ACTIONS entry yet is still
  # checked (using the safe default), but logged AND flagged for review so
  # a human notices and categorizes it.
  def test_unmapped_association_logs_and_flags_for_review
    job = CheckForBrokenReferencesJob.new
    logged = []
    job.define_singleton_method(:log) { |msg| logged << msg }
    job.instance_variable_set(:@review_findings, [])

    job.send(:note_new_action_needed, APIKey, :not_a_real_association)

    default = CheckForBrokenReferencesJob::Checks::DEFAULT_ACTION
    assert_includes(logged.last,
                    "NEEDS ACTION ENTRY: APIKey.not_a_real_association")
    assert_includes(logged.last, default.to_s)
    assert_includes(job.instance_variable_get(:@review_findings).last,
                    "NEEDS ACTION ENTRY: APIKey.not_a_real_association")
  end

  # Guards against drift in both directions now that the association LIST
  # itself is always derived live: a new belongs_to with no ACTIONS entry
  # logs "NEEDS ACTION ENTRY" (still checked, safely, but needs a human's
  # considered action); an ACTIONS entry naming an association that no
  # longer exists logs "STALE ACTIONS ENTRY". Neither should ever fire on
  # main - if this test fails, add/remove the corresponding
  # CheckForBrokenReferencesJob::Checks::ACTIONS entry.
  def test_every_association_has_a_considered_actions_entry
    job = CheckForBrokenReferencesJob.new
    logged = []
    job.define_singleton_method(:log) { |msg| logged << msg }
    job.perform(dry_run: true)

    assert_empty(logged.grep(/NEEDS ACTION ENTRY/),
                 "New belongs_to found - add an entry to " \
                 "CheckForBrokenReferencesJob::Checks::ACTIONS:\n" \
                 "#{logged.grep(/NEEDS ACTION ENTRY/).join("\n")}")
    assert_empty(logged.grep(/STALE ACTIONS ENTRY/),
                 "ACTIONS names an association that no longer exists:\n" \
                 "#{logged.grep(/STALE ACTIONS ENTRY/).join("\n")}")
  end

  def test_model_from_file_rescues_unconstantizable_filename
    assert_nil(CheckForBrokenReferencesJob::Checks.send(
                 :model_from_file, "totally_not_a_real_model.rb"
               ))
  end

  # Name::Version doesn't declare its own `belongs_to :correct_spelling` -
  # it's borrowed from Name's reflection because name_versions.
  # correct_spelling_id exists. Name::Version does NOT get :description/
  # :rss_log/:synonym, though - those columns aren't versioned.
  def test_monomorphic_associations_borrows_version_column_reflections
    pairs = CheckForBrokenReferencesJob::Checks.monomorphic_associations

    assert_includes(pairs, [Name::Version, :correct_spelling])
    assert_includes(pairs, [Name::Version, :name])
    assert_includes(pairs, [Name::Version, :user])
    assert_not_includes(pairs, [Name::Version, :description])
    assert_not_includes(pairs, [Name::Version, :rss_log])
    assert_not_includes(pairs, [Name::Version, :synonym])
  end

  # Typed polymorphic "views" that scope on a shared polymorphic foreign
  # key aren't double-counted as separate monomorphic checks.
  def test_monomorphic_associations_excludes_polymorphic_belongs_to
    pairs = CheckForBrokenReferencesJob::Checks.monomorphic_associations

    assert_not_includes(pairs, [Comment, :target])
    assert_not_includes(pairs, [Interest, :target])
  end

  # The real bugs this feature found: polymorphic targets are derived from
  # the inverse `has_many ..., as: :target` declaration, not a hand-listed
  # pairing - so a target model with a real declaration is always found.
  def test_polymorphic_targets_derived_from_inverse_as_declarations
    checks = CheckForBrokenReferencesJob::Checks

    assert_equal([Image, Observation].sort_by(&:name),
                 checks.polymorphic_targets(ExternalLink, :target).
                   sort_by(&:name))
    assert_includes(checks.polymorphic_targets(Interest, :target),
                    LocationDescription)
    assert_includes(checks.polymorphic_targets(Interest, :target),
                    NameDescription)
  end

  def test_action_for_falls_back_to_default_action
    default = CheckForBrokenReferencesJob::Checks::DEFAULT_ACTION

    assert_equal(default, CheckForBrokenReferencesJob::Checks.action_for(
                            APIKey, :not_a_real_association
                          ))
    assert_not(CheckForBrokenReferencesJob::Checks.action_defined?(
                 APIKey, :not_a_real_association
               ))
  end

  def test_action_for_returns_the_actions_entry_when_present
    assert_equal(:delete,
                 CheckForBrokenReferencesJob::Checks.action_for(APIKey,
                                                                :user))
    assert(CheckForBrokenReferencesJob::Checks.action_defined?(APIKey,
                                                               :user))
  end

  # An ACTIONS entry naming a real live association is never "stale".
  def test_stale_action_entries_is_empty_for_a_real_association
    stale = CheckForBrokenReferencesJob::Checks.stale_action_entries

    assert_empty(stale)
  end

  private

  # Records the exceptions handed to the #alerts pipeline while alerting is
  # forced active, so tests can assert on what a run would post to Slack.
  def capture_alerts(&block)
    alerts = []
    ExceptionNotifier.stub(:notifiers, [:slack]) do
      ExceptionNotifier.stub(:notify_exception,
                             lambda { |exception, **_o|
                               alerts << exception
                             }, &block)
    end
    alerts
  end
end
