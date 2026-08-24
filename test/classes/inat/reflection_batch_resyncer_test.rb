# frozen_string_literal: true

require("test_helper")
require("json")

# Unit tests for Inat::ReflectionBatchResyncer, the scheduled daily sync.
# The iNat fetch is injected as a fake, so the tests exercise the
# due-selection, batching, watermark and per-status tallying without
# hitting the API. The per-reflection apply logic itself is covered by
# Inat::ReflectionResync / Inat::ObservationResyncer tests.
class Inat::ReflectionBatchResyncerTest < UnitTestCase
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
    @site = external_sites(:inaturalist)
  end

  def test_syncs_a_due_reflection_and_advances_both_watermarks
    @link.update_column(:last_synced_at, nil)

    counts = run_batch(found: { @id => @raw })

    assert_equal(1, counts[:synced])
    assert_not_nil(@link.reload.last_synced_at, "stamps the per-link time")
    assert_not_nil(@site.reload.last_successful_sync_at,
                   "advances the source watermark on a clean run")
  end

  def test_a_reflection_synced_within_the_interval_is_not_due
    @link.update_column(:last_synced_at, 1.hour.ago)

    fetcher = FakeFetcher.new([{ @id => @raw }, false])
    counts = Inat::ReflectionBatchResyncer.new(fetcher: fetcher).resync_all

    assert_equal(0, counts[:synced], "a just-synced reflection isn't due")
    assert_nil(fetcher.seen_ids, "nothing due -> no fetch")
  end

  def test_a_reflection_past_the_interval_is_due
    @link.update_column(:last_synced_at, 21.hours.ago)

    counts = run_batch(found: { @id => @raw })

    assert_equal(1, counts[:synced])
  end

  def test_an_editable_import_is_not_a_reflection_and_is_skipped
    @obs.update_column(:reflected_at, nil)
    @link.update_column(:last_synced_at, nil)

    counts = run_batch(found: { @id => @raw })

    assert_equal(0, counts.values.sum, "an editable import has nothing to do")
    assert_nil(@link.reload.last_synced_at)
  end

  def test_source_deleted_is_counted_and_mo_data_kept
    @obs.rss_log&.update_columns(notes: "20250101000000\n")
    @link.update_column(:last_synced_at, nil)
    before = @obs.where

    counts = run_batch(found: {}) # id present in neither -> deleted on iNat

    assert_equal(1, counts[:source_deleted])
    assert_equal(before, @obs.reload.where, "MO data must be kept")
    assert_not_nil(@link.reload.last_synced_at, "the check still stamps")
  end

  def test_a_fetch_failure_stamps_nothing_and_holds_the_watermark
    @link.update_column(:last_synced_at, nil)
    @site.update_column(:last_successful_sync_at, nil)

    counts = run_batch(found: {}, failed: true)

    assert_equal(1, counts[:fetch_failed])
    assert_nil(@link.reload.last_synced_at,
               "a transient failure stamps nothing")
    assert_nil(@site.reload.last_successful_sync_at,
               "a failed run must not advance the source watermark")
  end

  def test_no_inaturalist_site_is_a_no_op
    @site.destroy!

    assert_equal({}, Inat::ReflectionBatchResyncer.new.resync_all)
  end

  private

  def run_batch(found:, failed: false)
    fetcher = FakeFetcher.new([found, failed])
    Inat::ReflectionBatchResyncer.new(fetcher: fetcher).resync_all
  end

  def mock_raw(filename)
    JSON.parse(File.read("test/inat/#{filename}.txt"),
               symbolize_names: true)[:results].first
  end
end
