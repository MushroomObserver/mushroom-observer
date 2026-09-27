# frozen_string_literal: true

#  What MO has spent against an external site's rate limits (#5416,
#  #2320). One row per site per ten-minute bucket, counting requests made
#  and media bytes downloaded.
#
#  Ten-minute buckets because the published caps are sliding windows: iNat
#  asks for under 10,000 requests a day and blocks media downloads over
#  5 GB in an hour or 24 GB in a day. Summing six buckets gives a trailing
#  hour accurate to ten minutes; hourly rows could only sum calendar
#  hours, which a burst spanning two of them would slip past.
#
#  Rows are kept indefinitely -- a year is about 52,500 per site, a few
#  MB, and the history is what makes usage reporting possible.
#
#  == Class methods
#
#  record_request::     count one request against a site
#  record_media::       count downloaded bytes, resolving the site by host
#  requests_since::     requests in a trailing window
#  media_bytes_since::  bytes in a trailing window
#  bucket_for::         the bucket a time falls in
#
#  == Instance methods
#
#  bucket_end::         one bucket after +bucket_start+
#
class ExternalSiteUsage < AbstractModel
  belongs_to :external_site

  BUCKET = 10.minutes

  # Each published limit: the ExternalSite attribute holding it, the
  # window it covers, which counter to compare, and how to say it. The
  # limits themselves live on the site, so a new source is a row.
  Limit = Data.define(:attribute, :window, :counter, :units) do
    def label
      "#{counter == :requests ? "requests" : "media"}, trailing " \
        "#{window.inspect.delete_prefix("1 ")}"
    end
  end

  LIMITS = [
    Limit.new(attribute: :requests_per_minute_limit, window: 1.minute,
              counter: :requests, units: :count),
    Limit.new(attribute: :requests_per_day_limit, window: 1.day,
              counter: :requests, units: :count),
    Limit.new(attribute: :media_bytes_per_hour_limit, window: 1.hour,
              counter: :media_bytes, units: :bytes),
    Limit.new(attribute: :media_bytes_per_day_limit, window: 1.day,
              counter: :media_bytes, units: :bytes)
  ].freeze

  class << self
    def record_request(site, count: 1)
      add(site, requests: count)
    end

    # Attributes bytes to whichever site claims that host, and ignores a
    # download from anywhere else -- MO uploads by URL from other places
    # too, and those count against nobody's limit.
    def record_media(url, bytes)
      return if bytes.to_i <= 0

      site = ExternalSite.serving_media(host_of(url))
      add(site, media_bytes: bytes.to_i) if site
    end

    # What a site has spent against each limit it publishes, as
    # [limit, used, cap]. Skips limits the site leaves unset.
    def against_limits(site)
      return [] unless site

      LIMITS.filter_map do |limit|
        cap = site.send(limit.attribute)
        next if cap.blank?

        [limit, sum_since(site, limit.window, limit.counter), cap]
      end
    end

    def requests_since(site, window)
      sum_since(site, window, :requests)
    end

    def media_bytes_since(site, window)
      sum_since(site, window, :media_bytes)
    end

    # The bucket a time falls in, floored to BUCKET.
    def bucket_for(time = Time.zone.now)
      seconds = BUCKET.to_i
      Time.zone.at((time.to_i / seconds) * seconds)
    end

    private

    # One row per site per bucket, incremented in place. The unique index
    # turns a concurrent insert into RecordNotUnique rather than a
    # duplicate row, and the retry then increments what the other process
    # created.
    def add(site, requests: 0, media_bytes: 0)
      return unless site

      row = find_or_create_by!(external_site_id: site.id,
                               bucket_start: bucket_for)
      update_counters(row.id, requests: requests, media_bytes: media_bytes)
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def sum_since(site, window, column)
      return 0 unless site

      where(external_site_id: site.id).
        where(bucket_start: bucket_for(Time.zone.now - window)..).
        sum(column)
    end

    def host_of(url)
      URI.parse(url.to_s).host.to_s.downcase
    rescue URI::InvalidURIError
      ""
    end
  end

  def bucket_end
    bucket_start + BUCKET
  end
end
