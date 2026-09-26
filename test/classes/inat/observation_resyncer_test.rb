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

  # calostoma_lutescens is open (obscured: false), so its precise public
  # coordinate mirrors into MO along with date and notes.
  def test_synced_updates_scalar_core_and_stamps_last_synced_at
    result = resync(found: { @id => @raw }).first

    assert_equal(:synced, result.status)
    @obs.reload
    assert_equal(@fresh.when, @obs.when, "date should mirror the source")
    assert_equal(@fresh.notes, @obs.notes, "notes should mirror the source")
    assert_equal(@fresh.location, @obs.location, "location mirrors the source")
    # MO rounds coordinates to 4 decimals (Location.parse_latitude).
    assert_in_delta(@fresh.lat, @obs.lat.to_f, 1e-4, "lat mirrors the source")
    assert_in_delta(@fresh.lng, @obs.lng.to_f, 1e-4, "lng mirrors the source")
    assert_not(@obs.gps_hidden, "an open source is not gps_hidden")
    assert_not_nil(@link.reload.last_synced_at, "should stamp last_synced_at")
  end

  # An obscured source yields only iNat's blurred coordinate, so MO's
  # accurate imported one is left intact; gps_hidden mirrors the obscuring
  # so MO hides the coordinate it keeps (#4215).
  def test_an_obscured_source_hides_gps_but_keeps_the_coordinate
    @obs.update_columns(lat: 12.3456789, lng: -98.7654321, gps_hidden: false)
    @obs.reload
    original = @obs.slice(:lat, :lng, :where)
    original_location = @obs.location

    resync(found: { @id => obscured_raw })

    @obs.reload
    assert(@obs.gps_hidden, "gps_hidden mirrors the iNat obscuring")
    assert_equal(original_location, @obs.location, "location left intact")
    assert_equal(original["lat"], @obs.lat, "lat left intact")
    assert_equal(original["lng"], @obs.lng, "lng left intact")
    assert_equal(original["where"], @obs.where, "where left intact")
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

  # A placeholder synced by anyone but the iNat observer stays a skeleton:
  # only the snapshot notes, no sequences.
  def test_placeholder_stays_stripped_for_a_non_owner_sync
    @obs.update_column(:placeholder, true)
    raw = copyrightable_raw
    fresh = Inat::Obs.new(JSON.generate(raw))

    resync(found: { @id => raw }, requested_by: users(:rolf))

    @obs.reload
    assert(@obs.placeholder?, "A non-owner sync should keep the placeholder")
    assert_equal(fresh.skeleton_notes, @obs.notes,
                 "A placeholder's notes should be only the snapshot")
    assert_empty(@obs.sequences, "A placeholder should not sync sequences")
  end

  def test_placeholder_stays_stripped_for_the_scheduled_sync
    @obs.update_column(:placeholder, true)
    raw = copyrightable_raw

    resync(found: { @id => raw })

    @obs.reload
    assert(@obs.placeholder?, "A sync with no requester should not upgrade")
    assert_empty(@obs.sequences, "A placeholder should not sync sequences")
  end

  # The iNat observer asking for a sync upgrades the placeholder to a full
  # reflection; its MO owner is unchanged.
  def test_placeholder_upgrades_when_the_inat_observer_syncs
    @obs.update_column(:placeholder, true)
    owner = @obs.user
    raw = copyrightable_raw
    fresh = Inat::Obs.new(JSON.generate(raw))
    assert(fresh.sequences.any?, "Test requires a source with a sequence")
    requester = users(:rolf)
    requester.update_column(:inat_username, raw[:user][:login].upcase)
    @obs.rss_log.update_columns(notes: "20250101000000\n")

    result = resync(found: { @id => raw }, requested_by: requester).first

    assert_equal(:synced, result.status, "An upgrade should count as synced")
    @obs.reload
    assert_not(@obs.placeholder?, "The owner's sync should upgrade it")
    assert_equal(fresh.notes, @obs.notes,
                 "An upgraded reflection should get the full notes")
    assert_equal(fresh.sequences.size, @obs.sequences.count,
                 "An upgraded reflection should get the sequences")
    assert_equal(owner, @obs.user, "The MO owner should be unchanged")
    assert_match(/#{requester.login}/, @obs.rss_log.reload.notes.to_s,
                 "The upgrade should be logged against the requester")
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

  # The aggregate flash goes to EVERY member's channel -- a viewer may be
  # on the non-reflection primary's page. The changed reflection's page
  # refreshes with the flash; the unchanged primary's page takes the
  # flash and the new sync time in place.
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

    primary_tags = stream_tags(primary_msgs)
    assert_equal(%w[update replace], primary_tags.pluck("action"),
                 "the primary's page gets the flash and the sync time")
    assert_equal("page_flash", primary_tags.first["target"])
    assert_equal(".reflection-last-synced", primary_tags.last["targets"])
    assert_equal(%w[refresh_with_flash], stream_tags(obs_msgs).pluck("action"),
                 "the synced reflection's page gets one refresh")
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

    refresh = stream_tags(messages).find do |tag|
      tag["action"] == "refresh_with_flash"
    end
    flash = flash_in(refresh)
    assert_includes(flash.text,
                    :observation_resync_synced.t(count: 1).as_displayed)
    assert_includes(flash.text,
                    :observation_resync_source_deleted.t(count: 1).as_displayed)
    assert_includes(flash.classes, "alert-warning",
                    "a missing source should drive the level to warning")
    assert_not_nil(sib_link.reload.last_synced_at,
                   "the deleted-source check still stamps last_synced_at")
  end

  # ---------------------------------------------------------------
  #  Broadcast shapes for single-reflection outcomes
  # ---------------------------------------------------------------

  # A real change refreshes the page, so each viewer refetches the
  # namings panel and title with their session; the flash rides along.
  def test_synced_refreshes_the_page_carrying_the_flash
    messages = capture_broadcasts(stream(@obs)) do
      resync(found: { @id => @raw })
    end

    tags = stream_tags(messages)
    assert_equal(%w[refresh_with_flash], tags.pluck("action"))
    assert_equal(:observation_resync_synced.t(count: 1).as_displayed,
                 flash_in(tags.first).text)
  end

  # No change: no refresh, just the flash and the new sync time.
  def test_unchanged_broadcasts_flash_and_sync_time
    resync(found: { @id => @raw }) # first sync, becomes the baseline
    @obs = Observation.find(@obs.id)

    messages = capture_broadcasts(stream(@obs)) do
      resync(found: { @id => @raw })
    end

    flash_tag, sync_tag = stream_tags(messages)
    assert_equal(2, messages.length)
    assert_equal(:observation_resync_unchanged.t.as_displayed,
                 flash_in(flash_tag).text)
    assert_equal(".reflection-last-synced", sync_tag["targets"])
    assert_not_nil(
      sync_tag.at_css("template .reflection-last-synced " \
                      "[data-controller='local-time']"),
      "the replacement shows the sync time"
    )
  end

  def test_source_deleted_broadcasts_warning_flash_and_sync_time
    @obs.rss_log.update_columns(notes: "20250101000000\n")

    messages = capture_broadcasts(stream(@obs)) { resync(found: {}) }

    flash_tag, sync_tag = stream_tags(messages)
    assert_equal(2, messages.length, "flash and the new sync time")
    flash = flash_in(flash_tag)
    assert_equal(:observation_resync_source_deleted.t(count: 1).as_displayed,
                 flash.text)
    assert_includes(flash.classes, "alert-warning")
    assert_equal(".reflection-last-synced", sync_tag["targets"])
  end

  def test_fetch_failed_broadcasts_danger_flash_only
    messages = capture_broadcasts(stream(@obs)) do
      resync(found: {}, failed: true)
    end

    assert_equal(1, messages.length)
    flash = flash_in(stream_tags(messages).first)
    assert_equal(:observation_resync_failed.t.as_displayed, flash.text)
    assert_includes(flash.classes, "alert-danger")
  end

  private

  # Broadcasts are turbo-stream markup; parse them so assertions select
  # elements instead of matching substrings.
  def stream_tags(messages)
    messages.map { |m| Nokogiri::HTML5.fragment(m).at_css("turbo-stream") }
  end

  def flash_in(tag)
    flash = tag.at_css("template #flash_notices")
    assert_not_nil(flash, "stream should carry a flash")
    flash
  end

  def stream(obs)
    Turbo::StreamsChannel.send(:stream_name_from, [obs, :external_link_sync])
  end

  def resync(found:, failed: false, requested_by: nil)
    fetcher = FakeFetcher.new([found, failed])
    Inat::ObservationResyncer.new(@obs, requested_by: requested_by,
                                        fetcher: fetcher).resync
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
      relationship: :import, external_id: 67_890
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

  # The calostoma raw plus the content a skeleton leaves out: a
  # description and a DNA sequence observation field.
  def copyrightable_raw
    dna_field = mock_raw("donadinia_PNW01")[:ofvs].
                find { |field| field[:datatype] == "dna" }
    assert_not_nil(dna_field, "Test requires a DNA observation field")
    @raw.merge(description: "Copyrightable description",
               ofvs: [dna_field])
  end

  # The open calostoma raw, flipped to obscured -- the flag iNat sets when
  # it blurs the public coordinate (user or taxon geoprivacy).
  def obscured_raw
    @raw.merge(obscured: true)
  end
end
