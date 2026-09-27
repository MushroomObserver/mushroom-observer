# frozen_string_literal: true

#  What MO has exchanged with an external site (#5416, #2320). One row per
#  site per ten-minute bucket, counting requests made and bytes moved in
#  each direction.
#
#  Ten-minute buckets because published caps tend to be sliding windows:
#  iNat asks for under 10,000 requests a day and blocks downloads over
#  5 GB in an hour or 24 GB in a day. Summing six buckets gives a trailing
#  hour accurate to ten minutes; hourly rows could only sum calendar
#  hours, which a burst spanning two of them would slip past.
#
#  Counting is worth doing whether or not a site enforces anything. iNat
#  is an API exchange where MO only pulls; a file-based exchange (MO
#  pushes Darwin Core Archives to MyCoPortal, #4216) moves data both ways
#  and may have no published limit, and "how much have we sent them, and
#  when" is still worth knowing.
#
#  Rows are kept indefinitely -- a year is about 52,500 per site, a few
#  MB, and the history is what makes usage reporting possible.
#
#  == Class methods
#
#  record_request::    count a request against a site
#  record_download::   count bytes pulled, resolving the site by host
#  record_transfer::   count requests and bytes for a known site
#  requests_since::    requests in a trailing window
#  bytes_in_since::    bytes pulled in a trailing window
#  bytes_out_since::   bytes sent in a trailing window
#  against_limits::    usage beside each limit a site publishes
#  bucket_for::        the bucket a time falls in
#
#  == Instance methods
#
#  bucket_end::        one bucket after +bucket_start+
#
class ExternalSiteUsage < AbstractModel
  belongs_to :external_site

  BUCKET = 10.minutes

  # Each limit a site may publish: the ExternalSite attribute holding it,
  # the window it covers, which counter to compare, and how to say it.
  # The values live on the site, so a new source is a row.
  Limit = Data.define(:attribute, :window, :counter, :units) do
    def label
      "#{counter.to_s.tr("_", " ")}, trailing " \
        "#{window.inspect.delete_prefix("1 ")}"
    end
  end

  LIMITS = [
    Limit.new(attribute: :requests_per_minute_limit, window: 1.minute,
              counter: :requests, units: :count),
    Limit.new(attribute: :requests_per_day_limit, window: 1.day,
              counter: :requests, units: :count),
    Limit.new(attribute: :bytes_in_per_hour_limit, window: 1.hour,
              counter: :bytes_in, units: :bytes),
    Limit.new(attribute: :bytes_in_per_day_limit, window: 1.day,
              counter: :bytes_in, units: :bytes)
  ].freeze

  COUNTERS = [:requests, :bytes_in, :bytes_out].freeze

  class << self
    def record_request(site, count: 1)
      add(site, requests: count)
    end

    # Attributes pulled bytes to whichever site claims that host, and
    # ignores a download from anywhere else -- MO downloads by URL from
    # places belonging to no site.
    def record_download(url, bytes)
      return if bytes.to_i <= 0

      site = ExternalSite.serving_media(host_of(url))
      add(site, bytes_in: bytes.to_i) if site
    end

    # For an exchange that knows its site without consulting a host: a
    # file pushed to a site, or an API client counting its traffic.
    def record_transfer(site, requests: 0, bytes_in: 0, bytes_out: 0)
      add(site, requests: requests, bytes_in: bytes_in,
                bytes_out: bytes_out)
    end

    # What a site has spent beside each limit it publishes, as
    # [limit, used, cap]. Empty for a site that publishes none, which is
    # not the same as a site with no usage.
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

    def bytes_in_since(site, window)
      sum_since(site, window, :bytes_in)
    end

    def bytes_out_since(site, window)
      sum_since(site, window, :bytes_out)
    end

    # Every counter over a window, for reporting a site with no limits.
    def totals_since(site, window)
      COUNTERS.index_with { |counter| sum_since(site, window, counter) }
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
    def add(site, requests: 0, bytes_in: 0, bytes_out: 0)
      return unless site

      row = find_or_create_by!(external_site_id: site.id,
                               bucket_start: bucket_for)
      update_counters(row.id, requests: requests, bytes_in: bytes_in,
                              bytes_out: bytes_out)
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
