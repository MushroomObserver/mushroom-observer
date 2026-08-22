# frozen_string_literal: true

require("test_helper")
require("json")

# Unit tests for Inat::ObservationResyncer. The iNat fetch is injected as
# a fake so the tests exercise the resync logic (update / no-op / deleted
# source / transient failure / occurrence-wide batching) without hitting
# the API.
class Inat::ObservationResyncerTest < UnitTestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper

  # Stands in for Inat::ObsFetcher — returns a canned [by_id, failed?]
  # and records the ids it was asked for.
  FakeFetcher = Struct.new(:batch, :seen_ids) do
    def fetch_batch(ids)
      self.seen_ids = ids
      batch
    end
  end

  def setup
    @obs = observations(:imported_inat_obs)
    @obs.update_column(:reflected_at, Time.zone.now)
    @link = @obs.import_link
    @id = @link.external_id.to_s
    @raw = mock_raw("calostoma_lutescens")
    @fresh = Inat::Obs.new(JSON.generate(@raw))
  end

  def test_synced_updates_scalar_core_and_stamps_last_synced_at
    result = resync(found: { @id => @raw }).first

    assert_equal(:synced, result.status)
    @obs.reload
    assert_equal(@fresh.when, @obs.when, "date should mirror the source")
    assert_equal(@fresh.location, @obs.location, "location mirrors the source")
    assert_equal(@fresh.notes, @obs.notes, "notes should mirror the source")
    assert_not_nil(@link.reload.last_synced_at, "should stamp last_synced_at")
  end

  # Sync is owned by the admin account: anyone logged in may trigger it
  # and the scheduled batch has no triggering user, so every resync log
  # is attributed to the system actor.
  def test_resync_is_logged_against_the_admin
    @obs.rss_log.update_columns(notes: "20250101000000\n")

    resync(found: { @id => @raw })

    assert_match(/#{User.admin.login}/, @obs.rss_log.reload.notes.to_s,
                 "a resync should be logged as the admin user")
  end

  def test_second_resync_with_same_data_is_unchanged
    assert_equal(:synced, resync(found: { @id => @raw }).first.status)
    # Reload as the background job would (fresh GlobalID deserialization);
    # the second sync of identical data is then a no-op.
    @obs = Observation.find(@obs.id)

    assert_equal(:unchanged, resync(found: { @id => @raw }).first.status,
                 "re-syncing identical data should be a no-op")
  end

  def test_source_deleted_keeps_data_logs_and_stamps
    # A well-formed (timestamp-led) rss_log, so the #4763 orphan guard
    # doesn't short-circuit the append.
    @obs.rss_log.update_columns(notes: "20250101000000\n")
    before = @obs.where

    result = resync(found: {}).first # present, not failed -> deleted on iNat

    assert_equal(:source_deleted, result.status)
    assert_equal(before, @obs.reload.where, "MO data must be kept")
    assert_not_nil(@link.reload.last_synced_at)
    assert_match(/log_observation_source_deleted/,
                 @obs.rss_log.reload.notes.to_s,
                 "the vanished source should be logged")
  end

  def test_fetch_failed_touches_nothing
    before = @obs.where

    result = resync(found: {}, failed: true).first

    assert_equal(:fetch_failed, result.status)
    assert_equal(before, @obs.reload.where)
    assert_nil(@link.reload.last_synced_at,
               "a transient failure must not stamp last_synced_at")
  end

  def test_non_reflection_is_left_alone
    @obs.update_column(:reflected_at, nil)

    assert_no_broadcasts(stream(@obs)) do
      assert_empty(resync(found: { @id => @raw }),
                   "an editable import has nothing to sync")
    end
    assert_nil(@link.reload.last_synced_at)
  end

  # ---------------------------------------------------------------
  #  Placeholder (skeleton, #4828) resync: narrower than a full
  #  reflection -- date/location sync automatically, notes/specimen
  #  never do, and a leading-ID change revises the existing Naming
  #  in place instead of adding a second one.
  # ---------------------------------------------------------------

  def test_placeholder_resync_syncs_date_location_not_notes_or_specimen
    skeleton = build_skeleton(name: names(:coprinus))
    original_notes = skeleton.notes
    naming = skeleton.namings.first
    original_reason = naming.reasons[2]
    link = skeleton.import_link
    coprinus_raw = mock_raw("coprinus")

    result = Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                false])
    ).resync.first

    assert_equal(:synced, result.status,
                 "date/location differ from the skeleton's fixed test " \
                 "values, so this should count as a real change")
    skeleton.reload
    fresh = Inat::Obs.new(JSON.generate(coprinus_raw))
    assert_equal(fresh.when, skeleton.when, "date should sync")
    assert_equal(fresh.location, skeleton.location, "location should sync")
    assert_equal(original_notes, skeleton.notes,
                 "placeholder notes must never be overwritten by source " \
                 "data -- SkeletonObservationBuilder never copies iNat's " \
                 "own notes in either")
    assert_not(skeleton.specimen?,
               "specimen should be left alone by a placeholder resync")
    assert_equal(names(:coprinus), skeleton.reload.name,
                 "leading ID is unchanged, so the naming shouldn't move")
    assert_equal(original_reason, naming.reload.reasons[2],
                 "unchanged leading ID: the naming's reason shouldn't " \
                 "be rewritten either")
  end

  def test_placeholder_resync_revises_naming_when_leading_id_changes
    skeleton = build_skeleton(name: names(:peltigera))
    naming = skeleton.namings.first
    link = skeleton.import_link
    coprinus_raw = mock_raw("coprinus")

    result = Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                false])
    ).resync.first

    assert_equal(:synced, result.status)
    assert_equal(1, skeleton.reload.namings.count,
                 "the existing Naming should be revised, not doubled")
    assert_equal(names(:coprinus), skeleton.name,
                 "leading ID changed on iNat: Observation#name should " \
                 "follow it")
    assert_equal(names(:coprinus).text_name, skeleton.text_name)
    naming.reload
    assert_equal(names(:coprinus), naming.name,
                 "the skeleton's initial Naming should be revised in " \
                 "place to the new leading ID")
    assert_match(
      /#{Time.zone.today.strftime("%Y-%m-%d")}\z/, naming.reasons[2],
      "the naming's 'Used references' reason should cite today's date"
    )
  end

  # Regression: a placeholder resync must track the pure Leading ID even
  # when the iNat obs carries a "Species Name Override" observation
  # field -- same rule as at initial import (#4828).
  def test_placeholder_resync_ignores_name_override
    skeleton = build_skeleton(name: names(:peltigera))
    link = skeleton.import_link
    coprinus_raw = mock_raw("coprinus").merge(
      ofvs: [{ name: "Species Name Override", value: "Boletus" }]
    )

    Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                false])
    ).resync

    assert_equal(names(:coprinus), skeleton.reload.name,
                 "Resync should track the community taxon (Coprinus), " \
                 "not the 'Species Name Override' field (Boletus)")
  end

  # Regression: same rule for a "Provisional Species Name" field.
  def test_placeholder_resync_ignores_provisional_name
    skeleton = build_skeleton(name: names(:peltigera))
    link = skeleton.import_link
    coprinus_raw = mock_raw("coprinus").merge(
      ofvs: [{ name: "Provisional Species Name", value: "Boletus" }]
    )

    Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                false])
    ).resync

    assert_equal(names(:coprinus), skeleton.reload.name,
                 "Resync should track the community taxon (Coprinus), " \
                 "not the 'Provisional Species Name' field (Boletus)")
  end

  # Defensive: a placeholder's sole Naming could in principle be removed
  # later (namings may be freely added/destroyed on a reflection -- only
  # the scalar edit form is locked). sync_placeholder_naming must not
  # raise when there's nothing to revise; date/location still sync.
  def test_placeholder_resync_with_no_naming_present
    skeleton = build_skeleton(name: names(:coprinus))
    skeleton.namings.first.destroy
    link = skeleton.import_link
    coprinus_raw = mock_raw("coprinus")

    result = Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                false])
    ).resync.first

    assert_equal(:synced, result.status)
    assert_empty(skeleton.reload.namings)
  end

  def test_placeholder_resync_leaves_non_placeholder_namings_alone
    non_placeholder = observations(:coprinus_comatus_obs)
    assert_not(non_placeholder.placeholder?,
               "test fixture should not be a placeholder")
    non_placeholder.update_column(:reflected_at, Time.zone.now)
    link = ExternalLink.create!(
      user: non_placeholder.user, target: non_placeholder,
      external_site: external_sites(:inaturalist), relationship: :import,
      external_id: 55_443_322,
      url: "https://www.inaturalist.org/observations/55443322"
    )

    Inat::ObservationResyncer.new(
      non_placeholder,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => @raw }, false])
    ).resync

    assert_equal(@fresh.notes, non_placeholder.reload.notes,
                 "a non-placeholder reflection keeps syncing notes as " \
                 "before -- the narrower rule is placeholder-only")
  end

  # ---------------------------------------------------------------
  #  Placeholder resync respects MO-side Namings and Votes: it only
  #  revises its own stand-in Naming, only while no outside vote
  #  has locked it. A locked stand-in gets a new one instead; a
  #  Naming someone else proposed stays untouched.
  # ---------------------------------------------------------------

  def test_placeholder_resync_leaves_independent_naming_untouched
    skeleton = build_skeleton(name: names(:peltigera))
    marys_naming = Naming.create!(observation: skeleton, user: mary,
                                  name: names(:coprinus), reasons: { 1 => "" })
    Vote.create!(naming: marys_naming, observation: skeleton, user: mary,
                 value: Vote::MAXIMUM_VOTE)
    Observation::NamingConsensus.new(skeleton).calc_consensus(mary)
    assert_equal(names(:coprinus), skeleton.reload.name,
                 "Test setup: Mary's confident vote should already lead")

    link = skeleton.import_link
    stereum_raw = raw_for(names(:stereum))

    Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => stereum_raw },
                                false])
    ).resync

    assert_equal(names(:coprinus), skeleton.reload.name,
                 "Mary's independently-proposed Naming should still win " \
                 "consensus after resync, not iNat's new Leading ID")
    assert_equal(names(:coprinus), marys_naming.reload.name,
                 "Resync should not repoint a Naming a human proposed " \
                 "independently")
    assert_equal(1, marys_naming.votes.count,
                 "Mary's vote on her own Naming should be untouched")
  end

  def test_placeholder_resync_forks_a_new_naming_when_the_anchor_is_locked
    skeleton = build_skeleton(name: names(:peltigera))
    anchor = skeleton.namings.first
    Vote.create!(naming: anchor, observation: skeleton, user: mary,
                 value: Vote::MAXIMUM_VOTE)
    link = skeleton.import_link
    coprinus_raw = raw_for(names(:coprinus))

    Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                false])
    ).resync

    assert_equal(names(:peltigera), anchor.reload.name,
                 "A locked Naming should not be revised by resync")
    assert_equal(2, skeleton.reload.namings.count,
                 "resync should add a new Naming instead of editing a " \
                 "locked one")
    forked = skeleton.namings.where.not(id: anchor.id).first
    assert_equal(names(:coprinus), forked.name)
    assert_equal(users(:rolf), forked.user,
                 "The forked Naming should be attributed to the importer")
  end

  # A forked stand-in's own vote uses the same confidence weight a
  # skeleton's initial Naming would get (SkeletonObservationBuilder#
  # naming_vote): Promising for Research Grade, Could Be otherwise.
  def test_placeholder_resync_fork_vote_reflects_research_grade
    skeleton = build_skeleton(name: names(:peltigera))
    anchor = skeleton.namings.first
    Vote.create!(naming: anchor, observation: skeleton, user: mary,
                 value: Vote::MAXIMUM_VOTE)
    link = skeleton.import_link
    research_raw = raw_for(names(:coprinus), quality_grade: "research")

    Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => research_raw },
                                false])
    ).resync

    forked = skeleton.reload.namings.where.not(id: anchor.id).first
    vote = forked.votes.find_by(user: users(:rolf))
    assert_equal(Vote::NEXT_BEST_VOTE, vote.value,
                 "A Research Grade source should give the forked stand-in " \
                 "a Promising vote, not Could Be")
  end

  def test_placeholder_resync_forked_naming_is_a_stable_anchor
    skeleton = build_skeleton(name: names(:peltigera))
    anchor = skeleton.namings.first
    Vote.create!(naming: anchor, observation: skeleton, user: mary,
                 value: Vote::MAXIMUM_VOTE)
    link = skeleton.import_link
    coprinus_raw = raw_for(names(:coprinus))
    Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                false])
    ).resync
    skeleton = Observation.find(skeleton.id)

    result = Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                false])
    ).resync.first

    assert_equal(:unchanged, result.status,
                 "iNat's Leading ID hasn't moved since the fork, so no " \
                 "further Naming should be added")
    assert_equal(2, skeleton.reload.namings.count)
  end

  def test_placeholder_resync_forks_again_after_the_first_fork_is_locked
    skeleton = build_skeleton(name: names(:peltigera))
    original_anchor = skeleton.namings.first
    Vote.create!(naming: original_anchor, observation: skeleton, user: mary,
                 value: Vote::MAXIMUM_VOTE)
    link = skeleton.import_link
    coprinus_raw = raw_for(names(:coprinus))
    Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                false])
    ).resync
    skeleton = Observation.find(skeleton.id)
    first_fork = skeleton.namings.where.not(id: original_anchor.id).first
    Vote.create!(naming: first_fork, observation: skeleton, user: dick,
                 value: Vote::MAXIMUM_VOTE)
    stereum_raw = raw_for(names(:stereum))

    Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => stereum_raw },
                                false])
    ).resync
    skeleton = Observation.find(skeleton.id)

    assert_equal(3, skeleton.namings.count,
                 "an outside vote locking the first fork should trigger " \
                 "a second fork")
    assert_equal(names(:peltigera), original_anchor.reload.name)
    assert_equal(names(:coprinus), first_fork.reload.name)
    second_fork = skeleton.namings.
                  where.not(id: [original_anchor.id, first_fork.id]).first
    assert_equal(names(:stereum), second_fork.name)
  end

  # Do not suppress sync-driven consensus recalculation. It sends the
  # normal ConsensusChangeMailer notification.
  # Naming#create_emails (after_save callback) separately sends
  # its own naming-proposal notification for the revised Naming -- two
  # distinct, expected notifications to the same interested user.
  def test_placeholder_resync_consensus_change_notifies_interested_users
    skeleton = build_skeleton(name: names(:peltigera))
    Interest.create!(target: skeleton, user: katrina, state: true)
    link = skeleton.import_link
    coprinus_raw = raw_for(names(:coprinus))

    assert_enqueued_jobs(2, only: ActionMailer::MailDeliveryJob) do
      Inat::ObservationResyncer.new(
        skeleton,
        fetcher: FakeFetcher.new([{ link.external_id.to_s => coprinus_raw },
                                  false])
      ).resync
    end
  end

  # ---------------------------------------------------------------
  #  Upgrading a placeholder to a full import on sync.
  #  If the iNat obs is now licensed, or the importer is the collector,
  #  skip the narrow placeholder sync above in favor of a full
  #  rebuild, overwriting the existing Observation.
  # ---------------------------------------------------------------

  def test_upgrade_eligible_when_now_licensed
    skeleton = build_skeleton(name: names(:peltigera))
    fresh = licensed_upgrade_obs(license_code: "cc-by-nc", login: "someone")

    resyncer = Inat::ObservationResyncer.new(skeleton)

    assert(resyncer.send(:upgrade_eligible?, skeleton, fresh),
           "A now-licensed source should make a placeholder upgrade-eligible")
  end

  def test_upgrade_eligible_when_importer_is_collector
    skeleton = build_skeleton(name: names(:peltigera))
    skeleton.user.update!(inat_username: "someone")
    fresh = licensed_upgrade_obs(license_code: nil, login: "someone")

    resyncer = Inat::ObservationResyncer.new(skeleton)

    assert(
      resyncer.send(:upgrade_eligible?, skeleton, fresh),
      "The importer matching the iNat collector should make a " \
      "placeholder upgrade-eligible even though the source is unlicensed"
    )
  end

  def test_upgrade_ineligible_when_neither_trigger_fires
    skeleton = build_skeleton(name: names(:peltigera))
    fresh = licensed_upgrade_obs(license_code: nil, login: "someone")

    resyncer = Inat::ObservationResyncer.new(skeleton)

    assert_not(resyncer.send(:upgrade_eligible?, skeleton, fresh),
               "An unlicensed source with an unmatched collector should " \
               "leave the narrow placeholder sync unchanged")
  end

  def test_upgrade_ineligible_for_a_non_placeholder
    non_placeholder = observations(:coprinus_comatus_obs)
    fresh = licensed_upgrade_obs(license_code: "cc-by-nc", login: "someone")

    resyncer = Inat::ObservationResyncer.new(non_placeholder)

    assert_not(resyncer.send(:upgrade_eligible?, non_placeholder, fresh),
               "Only a placeholder is eligible for an upgrade")
  end

  def test_placeholder_upgrades_to_full_import_when_now_licensed
    skeleton = build_skeleton(name: names(:peltigera))
    comment = Comment.create!(user: users(:mary), target: skeleton,
                              summary: "s", comment: "c")
    occ = Occurrence.create!(user: skeleton.user, primary_observation: skeleton)
    skeleton.update!(occurrence: occ)
    link = skeleton.import_link
    raw = licensed_upgrade_raw(license_code: "cc-by-nc", login: "mycoprimus")

    result = Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => raw }, false])
    ).resync.first

    assert_equal(:synced, result.status)
    skeleton.reload
    assert_not(skeleton.placeholder?,
               "A now-licensed source should upgrade the placeholder")
    assert_equal(names(:coprinus), skeleton.name,
                 "Upgrade should build the full naming set from the " \
                 "fetched taxon")
    assert_equal(occ.id, skeleton.occurrence_id,
                 "Upgrade should leave the Occurrence association in place")
    assert_includes(skeleton.comments, comment,
                    "Upgrade should leave existing comments in place")
    assert_equal(1, ExternalLink.where(target: skeleton, target_type:
                                       "Observation", relationship: :import).
                   count,
                 "Upgrade should not create a duplicate import ExternalLink")
  end

  def test_placeholder_upgrades_to_full_import_when_importer_is_collector
    skeleton = build_skeleton(name: names(:peltigera))
    skeleton.user.update!(inat_username: "devin189")
    link = skeleton.import_link
    raw = licensed_upgrade_raw(license_code: nil, login: "devin189")

    result = Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => raw }, false])
    ).resync.first

    assert_equal(:synced, result.status)
    skeleton.reload
    assert_not(
      skeleton.placeholder?,
      "The Observation should upgrade from a placeholder if the importer " \
      "is the collector, even if the iNat obs is unlicensed"
    )
    assert_equal(names(:coprinus), skeleton.name)
  end

  def test_placeholder_stays_narrow_synced_when_neither_trigger_fires
    skeleton = build_skeleton(name: names(:coprinus))
    link = skeleton.import_link
    raw = licensed_upgrade_raw(license_code: nil, login: "someone_else")

    Inat::ObservationResyncer.new(
      skeleton,
      fetcher: FakeFetcher.new([{ link.external_id.to_s => raw }, false])
    ).resync

    assert(skeleton.reload.placeholder?,
           "Neither trigger fired, so the placeholder should not upgrade")
  end

  # ---------------------------------------------------------------
  #  Occurrence-wide sync (#4215): one fetch, aggregate reporting
  # ---------------------------------------------------------------

  # Every reflection in the occurrence is refreshed in ONE fetch_batch
  # call, whichever member the resyncer was handed.
  def test_occurrence_resync_refreshes_every_reflection_in_one_fetch
    sib, sib_link = add_sibling_reflection
    fetcher = FakeFetcher.new(
      [{ @id => @raw, sib_link.external_id.to_s => mock_raw("coprinus") },
       false]
    )

    results = Inat::ObservationResyncer.new(@obs, fetcher: fetcher).resync

    assert_equal([@id, sib_link.external_id.to_s].sort,
                 fetcher.seen_ids.map(&:to_s).sort,
                 "both reflections should go out in one batch")
    assert_equal([:synced, :synced], results.map(&:status))
    assert_not_nil(@link.reload.last_synced_at)
    assert_not_nil(sib_link.reload.last_synced_at)
    assert_not_nil(sib.reload.location || sib.where)
  end

  # The aggregate flash goes to EVERY member's channel — a viewer may be
  # on the non-reflection primary's page — while panel updates go only
  # to the changed reflection's own channel.
  def test_flash_broadcast_reaches_every_member_page
    primary = add_non_reflection_primary

    primary_msgs = nil
    obs_msgs = capture_broadcasts(stream(@obs)) do
      primary_msgs = capture_broadcasts(stream(primary)) do
        Inat::ObservationResyncer.new(
          primary, fetcher: FakeFetcher.new([{ @id => @raw }, false])
        ).resync
      end
    end

    assert_equal(1, primary_msgs.length,
                 "the primary's page gets the flash only")
    assert(primary_msgs.first.include?('target="page_flash"'))
    assert_equal(4, obs_msgs.length,
                 "the synced reflection's page gets flash + panels")
  end

  # Mixed outcomes (rare) are reported honestly in one flash: refreshed
  # count plus the missing-source count, at warning level.
  def test_mixed_outcomes_reported_in_one_flash
    @obs.rss_log.update_columns(notes: "20250101000000\n")
    sib, sib_link = add_sibling_reflection
    sib.rss_log&.update_columns(notes: "20250101000000\n")
    # @obs's id found and changed; sibling's id absent -> source deleted.
    fetcher = FakeFetcher.new([{ @id => @raw }, false])

    messages = capture_broadcasts(stream(@obs)) do
      Inat::ObservationResyncer.new(@obs, fetcher: fetcher).resync
    end

    flash = messages.find { |m| m.include?('target="page_flash"') }
    assert_includes(flash, :observation_resync_synced.t(count: 1))
    assert_includes(flash, :observation_resync_source_deleted.t(count: 1))
    assert_includes(flash, "alert-warning",
                    "a missing source should drive the level to warning")
    assert_not_nil(sib_link.reload.last_synced_at,
                   "the deleted-source check still stamps last_synced_at")
  end

  # ---------------------------------------------------------------
  #  Broadcast shapes for single-reflection outcomes
  # ---------------------------------------------------------------

  # A real change: one flash broadcast plus a replace of each panel that
  # actually displays resynced fields (Details: when/location/GPS;
  # NotesPanel: notes).
  def test_synced_broadcasts_flash_and_panel_updates
    messages = capture_broadcasts(stream(@obs)) do
      resync(found: { @id => @raw })
    end

    assert_equal(4, messages.length)
    assert(messages.any? { |m| m.include?('target="page_flash"') })
    assert(
      messages.any? { |m| m.include?('target="observation_details"') }
    )
    assert(messages.any? { |m| m.include?('target="observation_notes"') })
    assert(
      messages.any? { |m| m.include?('target="observation_name_info"') },
      "NameInfoPanel should also refresh, so 'About this taxon' tracks " \
      "any leading-ID change"
    )
    flash = messages.find { |m| m.include?('target="page_flash"') }
    assert_includes(flash, :observation_resync_synced.t(count: 1))
  end

  # No real change: just the flash, no point re-rendering panels whose
  # content didn't move.
  def test_unchanged_broadcasts_flash_only
    resync(found: { @id => @raw }) # first sync, becomes the baseline
    @obs = Observation.find(@obs.id)

    messages = capture_broadcasts(stream(@obs)) do
      resync(found: { @id => @raw })
    end

    assert_equal(1, messages.length)
    assert_includes(messages.first, :observation_resync_unchanged.t)
  end

  def test_source_deleted_broadcasts_warning_flash_only
    @obs.rss_log.update_columns(notes: "20250101000000\n")

    messages = capture_broadcasts(stream(@obs)) { resync(found: {}) }

    assert_equal(1, messages.length)
    assert_includes(messages.first,
                    :observation_resync_source_deleted.t(count: 1))
  end

  def test_fetch_failed_broadcasts_danger_flash_only
    messages = capture_broadcasts(stream(@obs)) do
      resync(found: {}, failed: true)
    end

    assert_equal(1, messages.length)
    assert_includes(messages.first, :observation_resync_failed.t)
  end

  private

  def stream(obs)
    Turbo::StreamsChannel.send(:stream_name_from, [obs, :external_link_sync])
  end

  def resync(found:, failed: false)
    fetcher = FakeFetcher.new([found, failed])
    Inat::ObservationResyncer.new(@obs, fetcher: fetcher).resync
  end

  # A second read-only reflection grouped into @obs's occurrence, with
  # its own iNat import link. Returns [observation, link].
  def add_sibling_reflection
    sib = observations(:minimal_unknown_obs)
    [sib, @obs].each { |o| o.update_column(:occurrence_id, nil) }
    occ = Occurrence.create!(user: @obs.user, primary_observation: @obs)
    @obs.update!(occurrence: occ)
    sib.update_column(:reflected_at, Time.zone.now)
    sib.update!(occurrence: occ)
    link = ExternalLink.create!(
      user: sib.user, target: sib,
      external_site: external_sites(:inaturalist),
      relationship: :import, external_id: 67_890,
      url: "https://www.inaturalist.org/observations/67890"
    )
    [sib, link]
  end

  # A non-reflection observation grouped as @obs's occurrence primary —
  # the page the article steers users toward pressing Sync from.
  def add_non_reflection_primary
    primary = observations(:detailed_unknown_obs)
    [primary, @obs].each { |o| o.update_column(:occurrence_id, nil) }
    occ = Occurrence.create!(user: primary.user,
                             primary_observation: primary)
    primary.update!(occurrence: occ)
    @obs.update!(occurrence: occ)
    primary
  end

  def mock_raw(filename)
    JSON.parse(File.read("test/inat/#{filename}.txt"),
               symbolize_names: true)[:results].first
  end

  # A raw iNat obs hash whose taxon matches an existing MO Name fixture
  # (genus rank), so leading-ID resolution needs no API call. Based on
  # coprinus.txt (unlicensed, one photo -- irrelevant here since these
  # tests only exercise placeholder naming/consensus sync).
  def raw_for(name, quality_grade: "needs_id")
    raw = mock_raw("coprinus").merge(quality_grade: quality_grade)
    raw.merge(taxon: raw[:taxon].merge(name: name.text_name, rank: "genus"))
  end

  # Minimal stand-in for an ::Inat::Obs, exposing only what
  # Inat::SkeletonObservationBuilder and Inat::LeadNameResolver read --
  # same shape as InatSkeletonObservationBuilderTest::FakeInatObs, kept
  # local so this file doesn't depend on another test file's fixture.
  class FakeSkeletonInatObs
    FAKE_INAT_ID = 99_887_766

    def initialize(name:)
      @name = name
    end

    attr_reader :name

    def collector = "A Collector"
    def provisional_name = nil
    def name_override = nil
    def when = Date.new(2024, 4, 29)
    def location = ::Location.find_by(name: "Albion, California, USA")
    def where = "Albion, California, USA"
    def lat = 44.0
    def lng = -123.0
    def gps_hidden = false # rubocop:disable Naming/PredicateMethod

    def [](key)
      { id: FAKE_INAT_ID, quality_grade: "needs_id", license_code: nil,
        identifications: [],
        user: { login: "danmorton", name: "Daniel Morton" } }[key]
    end
  end

  # A real skeleton Observation (Inat::SkeletonObservationBuilder), so
  # placeholder-resync tests exercise the real reflected_at/placeholder
  # state instead of stubbing it.
  def build_skeleton(name:)
    fake = FakeSkeletonInatObs.new(name: name)
    Inat::SkeletonObservationBuilder.new(
      inat_obs: fake, user: users(:rolf),
      external_site: external_sites(:inaturalist)
    ).mo_observation
  end

  # A raw iNat obs hash (calostoma_lutescens.txt has no photos, so an
  # upgrade doesn't trigger an image upload) with license_code and
  # collector overridden, and its taxon swapped for one that already
  # matches an MO Name fixture (Coprinus) so name resolution needs no
  # API call.
  def licensed_upgrade_raw(license_code:, login:)
    raw = mock_raw("calostoma_lutescens")
    raw.merge(
      license_code: license_code,
      taxon: raw[:taxon].merge(name: "Coprinus", rank: "genus"),
      user: raw[:user].merge(login: login)
    )
  end

  def licensed_upgrade_obs(license_code:, login:)
    Inat::Obs.new(
      JSON.generate(licensed_upgrade_raw(license_code: license_code,
                                         login: login))
    )
  end
end
