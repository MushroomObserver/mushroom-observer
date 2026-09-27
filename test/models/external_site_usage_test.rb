# frozen_string_literal: true

require("test_helper")

# Accounting for what MO spends against an external site's rate limits
# (#5416, #2320).
class ExternalSiteUsageTest < UnitTestCase
  def setup
    super
    @site = external_sites(:inaturalist)
  end

  def test_records_a_request_in_the_current_bucket
    ExternalSiteUsage.record_request(@site)

    row = ExternalSiteUsage.sole
    assert_equal(@site.id, row.external_site_id)
    assert_equal(1, row.requests)
    assert_equal(0, row.bytes_in)
    assert_equal(ExternalSiteUsage.bucket_for, row.bucket_start)
  end

  # One row per site per bucket, incremented rather than duplicated.
  def test_accumulates_into_one_row_per_bucket
    3.times { ExternalSiteUsage.record_request(@site) }
    ExternalSiteUsage.record_request(@site, count: 7)

    assert_equal(1, ExternalSiteUsage.count)
    assert_equal(10, ExternalSiteUsage.sole.requests)
  end

  def test_buckets_are_ten_minutes_wide
    time = Time.zone.parse("2026-09-26 14:37:42")
    bucket = ExternalSiteUsage.bucket_for(time)

    assert_equal(Time.zone.parse("2026-09-26 14:30:00"), bucket)
    assert_equal(Time.zone.parse("2026-09-26 14:40:00"),
                 ExternalSiteUsage.new(bucket_start: bucket).bucket_end)
  end

  def test_separate_times_land_in_separate_buckets
    early = ExternalSiteUsage.bucket_for(Time.zone.parse("2026-09-26 14:31"))
    late = ExternalSiteUsage.bucket_for(Time.zone.parse("2026-09-26 14:41"))

    assert_not_equal(early, late)
  end

  # iNat serves open-licence photos from S3 and the rest from its CDN.
  def test_attributes_media_from_a_known_host
    ExternalSiteUsage.record_download(
      "https://inaturalist-open-data.s3.amazonaws.com/photos/1/original.jpg",
      2_800_000
    )

    assert_equal(2_800_000, ExternalSiteUsage.sole.bytes_in)
    assert_equal(@site.id, ExternalSiteUsage.sole.external_site_id)
  end

  def test_attributes_media_from_the_cdn_host
    ExternalSiteUsage.record_download(
      "https://static.inaturalist.org/photos/2/original.jpeg", 1_000
    )

    assert_equal(1_000, ExternalSiteUsage.sole.bytes_in)
  end

  # The hosts live on the site row, so another source needs no code
  # change to be counted.
  def test_attributes_media_to_whichever_site_claims_the_host
    other = external_sites(:mycoportal)
    other.update!(media_hosts: "images.mycoportal.org")

    ExternalSiteUsage.record_download("https://images.mycoportal.org/a.jpg", 99)

    assert_equal(99, ExternalSiteUsage.bytes_in_since(other, 1.hour))
    assert_equal(0, ExternalSiteUsage.bytes_in_since(@site, 1.hour))
  end

  # The caps live on the site too, so this reports whatever it publishes.
  def test_against_limits_reports_each_published_limit
    ExternalSiteUsage.record_request(@site, count: 5)

    rows = ExternalSiteUsage.against_limits(@site)

    assert_equal(4, rows.size, "iNat publishes four limits in the fixture")
    attributes = rows.map { |limit, _used, _cap| limit.attribute }
    assert_includes(attributes, :requests_per_day_limit)
    assert_includes(attributes, :bytes_in_per_hour_limit)
    day = rows.find { |l, _u, _c| l.attribute == :requests_per_day_limit }
    assert_equal(5, day[1])
    assert_equal(10_000, day[2])
  end

  def test_against_limits_skips_limits_a_site_leaves_unset
    assert_empty(ExternalSiteUsage.against_limits(external_sites(:mycoportal)))
  end

  def test_against_limits_of_no_site
    assert_empty(ExternalSiteUsage.against_limits(nil))
  end

  def test_limit_labels_name_the_counter_and_window
    labels = ExternalSiteUsage::LIMITS.map(&:label)

    assert_includes(labels, "requests, trailing day")
    assert_includes(labels, "bytes in, trailing hour")
  end

  # MO uploads by URL from other places, and those count against nobody.
  def test_ignores_media_from_an_untracked_host
    ExternalSiteUsage.record_download("https://example.org/photo.jpg",
                                      5_000_000)

    assert_empty(ExternalSiteUsage.all)
  end

  def test_ignores_a_zero_or_missing_byte_count
    url = "https://static.inaturalist.org/photos/3/original.jpeg"
    ExternalSiteUsage.record_download(url, 0)
    ExternalSiteUsage.record_download(url, nil)

    assert_empty(ExternalSiteUsage.all)
  end

  def test_ignores_an_unparseable_url
    assert_nothing_raised do
      ExternalSiteUsage.record_download("http://[bad", 100)
    end
    assert_empty(ExternalSiteUsage.all)
  end

  # The rolling window is what the caps are expressed in: 5 GB in the
  # trailing hour, 10,000 requests in the trailing day.
  def test_sums_a_trailing_window_and_excludes_older_buckets
    inside = ExternalSiteUsage.bucket_for(20.minutes.ago)
    outside = ExternalSiteUsage.bucket_for(3.hours.ago)
    ExternalSiteUsage.create!(external_site: @site, bucket_start: inside,
                              requests: 5, bytes_in: 1_000)
    ExternalSiteUsage.create!(external_site: @site, bucket_start: outside,
                              requests: 99, bytes_in: 9_000)

    assert_equal(5, ExternalSiteUsage.requests_since(@site, 1.hour))
    assert_equal(1_000, ExternalSiteUsage.bytes_in_since(@site, 1.hour))
    assert_equal(104, ExternalSiteUsage.requests_since(@site, 1.day))
    assert_equal(10_000, ExternalSiteUsage.bytes_in_since(@site, 1.day))
  end

  def test_sums_only_the_site_asked_about
    other = external_sites(:mycoportal)
    ExternalSiteUsage.record_request(@site, count: 4)
    ExternalSiteUsage.record_request(other, count: 11)

    assert_equal(4, ExternalSiteUsage.requests_since(@site, 1.hour))
    assert_equal(11, ExternalSiteUsage.requests_since(other, 1.hour))
  end

  def test_a_window_with_no_usage_sums_to_zero
    assert_equal(0, ExternalSiteUsage.requests_since(@site, 1.hour))
    assert_equal(0, ExternalSiteUsage.bytes_in_since(@site, 1.hour))
  end

  # Two processes recording in the same bucket race: the unique index
  # turns the loser's insert into RecordNotUnique, and the retry then
  # increments the row the winner created rather than duplicating it.
  def test_a_concurrent_insert_retries_onto_the_existing_row
    calls = 0
    original = ExternalSiteUsage.method(:find_or_create_by!)
    racing = lambda do |**attrs|
      calls += 1
      raise(ActiveRecord::RecordNotUnique.new("duplicate")) if calls == 1

      original.call(**attrs)
    end

    ExternalSiteUsage.stub(:find_or_create_by!, racing) do
      ExternalSiteUsage.record_request(@site, count: 2)
    end

    assert_equal(2, calls, "the first attempt raised and was retried")
    assert_equal(1, ExternalSiteUsage.count)
    assert_equal(2, ExternalSiteUsage.sole.requests)
  end

  # A file-based exchange knows its site without consulting a host, and
  # sends as well as receives -- MO pushes Darwin Core Archives.
  def test_records_a_transfer_in_both_directions
    ExternalSiteUsage.record_transfer(@site, requests: 1,
                                             bytes_in: 10, bytes_out: 500)

    row = ExternalSiteUsage.sole
    assert_equal(1, row.requests)
    assert_equal(10, row.bytes_in)
    assert_equal(500, row.bytes_out)
    assert_equal(500, ExternalSiteUsage.bytes_out_since(@site, 1.hour))
  end

  # Counting is worth doing whether or not a site enforces anything, so a
  # site with no published limit still accumulates totals.
  def test_totals_for_a_site_with_no_published_limits
    other = external_sites(:mycoportal)
    ExternalSiteUsage.record_transfer(other, requests: 2, bytes_out: 4_096)

    assert_empty(ExternalSiteUsage.against_limits(other))
    totals = ExternalSiteUsage.totals_since(other, 1.day)
    assert_equal(2, totals[:requests])
    assert_equal(0, totals[:bytes_in])
    assert_equal(4_096, totals[:bytes_out])
  end

  def test_totals_cover_every_counter
    assert_equal([:requests, :bytes_in, :bytes_out],
                 ExternalSiteUsage.totals_since(@site, 1.day).keys)
  end

  # A nil site would otherwise create an orphan row.
  def test_a_missing_site_records_nothing
    ExternalSiteUsage.record_request(nil)

    assert_empty(ExternalSiteUsage.all)
    assert_equal(0, ExternalSiteUsage.requests_since(nil, 1.hour))
  end
end
