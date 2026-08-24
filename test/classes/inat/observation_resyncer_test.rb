# frozen_string_literal: true

require("test_helper")
require("json")

# Unit tests for Inat::ObservationResyncer. The iNat fetch is injected as
# a fake so the tests exercise the resync logic (update / no-op / deleted
# source / transient failure / occurrence-wide batching) without hitting
# the API.
class Inat::ObservationResyncerTest < UnitTestCase
  include ActionCable::TestHelper

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

  # specimen is MO-side (herbarium records / collection numbers a user may
  # add to a reflection); iNat gives no reliable signal, so a resync must
  # leave it alone rather than reset it to false.
  def test_resync_does_not_unset_specimen
    @obs.update_column(:specimen, true)

    resync(found: { @id => @raw })

    assert(@obs.reload.specimen, "resync must not unset a true specimen")
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
    assert_equal(3, obs_msgs.length,
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

    assert_equal(3, messages.length)
    assert(messages.any? { |m| m.include?('target="page_flash"') })
    assert(
      messages.any? { |m| m.include?('target="observation_details"') }
    )
    assert(messages.any? { |m| m.include?('target="observation_notes"') })
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
end
