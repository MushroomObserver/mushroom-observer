# frozen_string_literal: true

require("test_helper")
require("json")

# Unit tests for Inat::ObservationResyncer. The iNat fetch is injected as
# a fake so the tests exercise the resync logic (update / no-op / deleted
# source / transient failure / non-reflection) without hitting the API.
class Inat::ObservationResyncerTest < UnitTestCase
  # Stands in for Inat::ObsFetcher — returns a canned [by_id, failed?].
  FakeFetcher = Struct.new(:batch) do
    def fetch_batch(_ids)
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
    result = resync(found: { @id => @raw })

    assert_equal(:synced, result.status)
    @obs.reload
    assert_equal(@fresh.when, @obs.when, "date should mirror the source")
    assert_equal(@fresh.location, @obs.location, "location mirrors the source")
    assert_equal(@fresh.notes, @obs.notes, "notes should mirror the source")
    assert_not_nil(@link.reload.last_synced_at, "should stamp last_synced_at")
  end

  def test_second_resync_with_same_data_is_unchanged
    assert_equal(:synced, resync(found: { @id => @raw }).status)
    # Reload as the background job would (fresh GlobalID deserialization);
    # the second sync of identical data is then a no-op.
    @obs = Observation.find(@obs.id)

    assert_equal(:unchanged, resync(found: { @id => @raw }).status,
                 "re-syncing identical data should be a no-op")
  end

  def test_source_deleted_keeps_data_logs_and_stamps
    # A well-formed (timestamp-led) rss_log, so the #4763 orphan guard
    # doesn't short-circuit the append.
    @obs.rss_log.update_columns(notes: "20250101000000\n")
    before = @obs.where

    result = resync(found: {}) # present, not failed -> deleted on iNat

    assert_equal(:source_deleted, result.status)
    assert_equal(before, @obs.reload.where, "MO data must be kept")
    assert_not_nil(@link.reload.last_synced_at)
    assert_match(/log_observation_source_deleted/,
                 @obs.rss_log.reload.notes.to_s,
                 "the vanished source should be logged")
  end

  def test_fetch_failed_touches_nothing
    before = @obs.where

    result = resync(found: {}, failed: true)

    assert_equal(:fetch_failed, result.status)
    assert_equal(before, @obs.reload.where)
    assert_nil(@link.reload.last_synced_at,
               "a transient failure must not stamp last_synced_at")
  end

  def test_non_reflection_is_left_alone
    @obs.update_column(:reflected_at, nil)

    result = resync(found: { @id => @raw })

    assert_equal(:not_a_reflection, result.status)
    assert_nil(@link.reload.last_synced_at)
  end

  private

  def resync(found:, failed: false)
    fetcher = FakeFetcher.new([found, failed])
    Inat::ObservationResyncer.new(@obs, fetcher: fetcher).resync
  end

  def mock_raw(filename)
    JSON.parse(File.read("test/inat/#{filename}.txt"),
               symbolize_names: true)[:results].first
  end
end
