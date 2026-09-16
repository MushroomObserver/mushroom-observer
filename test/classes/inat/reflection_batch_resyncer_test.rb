# frozen_string_literal: true

require("test_helper")
require("json")

# Unit tests for Inat::ReflectionBatchResyncer, the scheduled daily sync.
# The iNat fetch is injected as a fake, so the tests exercise the
# incremental (updated_since) selection, batching, watermark and
# per-status tallying without hitting the API. The per-reflection apply
# logic itself is covered by the Inat::ReflectionResync /
# Inat::ObservationResyncer tests.
class Inat::ReflectionBatchResyncerTest < UnitTestCase
  # Stands in for Inat::ObsFetcher -- returns a canned [by_id, failed?]
  # and records the ids and updated_since it was asked for.
  FakeFetcher = Struct.new(:batch, :seen_ids, :seen_since, :seen_field) do
    def fetch_batch(ids, updated_since: nil, field_present: nil)
      self.seen_ids = ids
      self.seen_since = updated_since
      self.seen_field = field_present
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

  def test_syncs_a_changed_reflection_and_advances_the_watermark
    @site.update_column(:last_successful_sync_at, 3.days.ago)

    counts = run_batch(found: { @id => @raw })

    assert_equal(1, counts[:synced])
    assert_not_nil(@link.reload.last_synced_at, "stamps the per-link time")
    assert_operator(@site.reload.last_successful_sync_at, :>, 3.days.ago,
                    "advances the source watermark on a clean run")
  end

  def test_passes_the_source_watermark_as_updated_since
    since = 2.days.ago
    @site.update_column(:last_successful_sync_at, since)
    fetcher = FakeFetcher.new([{ @id => @raw }, false])

    Inat::ReflectionBatchResyncer.new(fetcher: fetcher).resync_all

    assert_not_nil(fetcher.seen_since)
    assert_in_delta(since.to_i, fetcher.seen_since.to_i, 1,
                    "the fetch is narrowed by the last successful run")
  end

  # Every batch fetch is constrained to obs carrying MO's back-link field,
  # the marker that says "this is a synced MO reflection".
  def test_constrains_the_fetch_to_the_mo_url_field
    fetcher = FakeFetcher.new([{ @id => @raw }, false])

    Inat::ReflectionBatchResyncer.new(fetcher: fetcher).resync_all

    assert_equal(Inat::Constants::MO_URL_OBSERVATION_FIELD_NAME,
                 fetcher.seen_field)
  end

  def test_first_run_with_no_watermark_fetches_everything
    @site.update_column(:last_successful_sync_at, nil)
    fetcher = FakeFetcher.new([{ @id => @raw }, false])

    Inat::ReflectionBatchResyncer.new(fetcher: fetcher).resync_all

    assert_nil(fetcher.seen_since,
               "no watermark -> full fetch, not an incremental one")
  end

  # An incremental fetch returns only changed ids, so a reflection absent
  # from the results is unchanged -- NOT deleted. Deletion detection is
  # the full-fetch "Sync now" button's job.
  def test_a_reflection_absent_from_the_results_is_unchanged_not_deleted
    @obs.rss_log&.update_columns(notes: "20250101000000\n")
    before = @obs.where

    counts = run_batch(found: {}) # nothing changed since the watermark

    assert_equal(1, counts[:unchanged])
    assert_equal(0, counts[:source_deleted])
    assert_equal(before, @obs.reload.where, "unchanged data is left alone")
    assert_no_match(/log_observation_source_deleted/,
                    @obs.rss_log.reload.notes.to_s,
                    "an absent id must not be logged as a deletion")
  end

  def test_an_editable_import_is_not_a_reflection_and_is_skipped
    @obs.update_column(:reflected_at, nil)

    counts = run_batch(found: { @id => @raw })

    assert_equal(0, counts.values.sum, "an editable import has nothing to do")
    assert_nil(@link.reload.last_synced_at)
  end

  def test_a_fetch_failure_holds_the_watermark_and_stamps_nothing
    @link.update_column(:last_synced_at, nil)
    @site.update_column(:last_successful_sync_at, nil)

    counts = run_batch(found: {}, failed: true)

    assert_equal(1, counts[:fetch_failed])
    assert_nil(@link.reload.last_synced_at,
               "a transient failure stamps nothing")
    assert_nil(@site.reload.last_successful_sync_at,
               "a failed run must not advance the source watermark")
  end

  # Stamping the bookkeeping watermark must not run full-record
  # validation: a production snapshot's iNaturalist site had an invalid
  # base_url, which blocked an update! but must not block the sync.
  def test_advances_the_watermark_even_when_the_site_row_is_invalid
    @site.update_column(:base_url, "not a url")
    @site.update_column(:last_successful_sync_at, 3.days.ago)
    assert(@site.invalid?, "the site row must be invalid for this test")

    run_batch(found: { @id => @raw })

    assert_operator(@site.reload.last_successful_sync_at, :>, 3.days.ago,
                    "the watermark advances despite the invalid site row")
  end

  # The MO URL back-link field should point at the reflection's own obs;
  # a match raises no alert.
  def test_no_back_link_alert_when_the_field_points_at_the_reflection
    raw = @raw.merge(ofvs: [mo_url_ofv(@obs.id)])
    resyncer = Inat::ReflectionBatchResyncer.new(
      fetcher: FakeFetcher.new([{ @id => raw }, false])
    )

    resyncer.resync_all

    assert_empty(resyncer.back_link_alerts)
  end

  # A back-link pointing at a different MO obs is collected for #alerts.
  def test_back_link_alert_when_the_field_points_elsewhere
    raw = @raw.merge(ofvs: [mo_url_ofv(@obs.id + 999)])
    resyncer = Inat::ReflectionBatchResyncer.new(
      fetcher: FakeFetcher.new([{ @id => raw }, false])
    )

    resyncer.resync_all

    assert_equal(1, resyncer.back_link_alerts.size)
    assert_includes(resyncer.back_link_alerts.first, @obs.id.to_s)
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

  def mo_url_ofv(mo_id)
    { field_id: Inat::Constants::MO_URL_OBSERVATION_FIELD_ID,
      name: "Mushroom Observer URL",
      value: "https://mushroomobserver.org/#{mo_id}" }
  end
end
