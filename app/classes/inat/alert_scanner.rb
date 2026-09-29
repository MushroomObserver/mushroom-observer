# frozen_string_literal: true

class Inat
  # The alert half of the cycle (#5416): one poll of iNaturalist for
  # everything identified as a taxon some project watches, matched
  # against each project locally, recorded, and grouped into one
  # message per admin.
  #
  # One query serves every alerting project -- the taxa are the union,
  # and the geometry is applied here rather than asked of iNat, which
  # also keeps the place-mapping hazard out of the alert path. Volume
  # is low: project 327's 17 taxa saw 47 observations worldwide in a
  # month.
  #
  # The watermark on the site says where the poll has reached. A site
  # with none set has its first cycle establish one and send nothing:
  # switching alerting on is not a request to hear about what was
  # identified last year.
  #
  # `without_field` is deliberately absent from the query the importer
  # and the preview both apply: a target name applied to an
  # observation MO already holds is still news.
  class AlertScanner
    include Inat::Constants
    include Inat::JsonFetch

    PAGE_SIZE = 200
    # Enough for a taxon swap landing on a watched name; past this the
    # cycle says so rather than walking iNat for a quarter of an hour.
    MAX_PAGES = 5

    attr_reader :alerts_sent, :warnings

    def initialize(site: ExternalSite.inaturalist)
      @site = site
      @alerts_sent = 0
      @warnings = []
    end

    # A Hash of User => Array of ProjectExternalSiteAlert, the digest
    # each admin is owed this cycle. Empty when nothing matched, when
    # no project is alerting, or when this cycle only set the
    # watermark.
    def scan
      criteria = Inat::AlertCriteria.all_alerting(@site)
      return {} if criteria.empty?

      # Stamped before the fetch, so anything identified while this run
      # is in flight is caught by the next one.
      @polled_at = Time.zone.now
      @since = @site.last_alert_poll_at
      return seed_watermark if @since.nil?

      digests = collect(criteria, fetch_candidates(criteria))
      @site.update(last_alert_poll_at: @polled_at)
      digests
    end

    private

    # The first cycle for a site establishes where the poll starts and
    # sends nothing.
    def seed_watermark
      @site.update(last_alert_poll_at: @polled_at)
      {}
    end

    def collect(criteria, candidates)
      digests = Hash.new { |hash, user| hash[user] = [] }
      candidates.each do |candidate|
        criteria.each do |criterion|
          alert = alert_for(criterion, candidate)
          next unless alert

          @alerts_sent += 1
          criterion.admins.each { |admin| digests[admin] << alert }
        end
      end
      digests
    end

    def alert_for(criterion, candidate)
      identification = criterion.alertable_identification(candidate)
      return nil unless identification
      return nil unless criterion.matches?(candidate)

      ProjectExternalSiteAlert.record(
        project: criterion.project, external_site: @site,
        identification: identification, observation: candidate.to_h
      )
    end

    # Everything identified as one of the watched taxa and touched
    # since the last cycle. `updated_since` rather than a creation
    # date, because a target name can be applied years after the
    # upload -- measured, one in seven arrives more than a day later.
    def fetch_candidates(criteria)
      taxa = criteria.flat_map(&:taxon_ids).uniq
      return [] if taxa.empty?

      pages(taxa).map { |result| Inat::AlertCandidate.new(result) }
    end

    def pages(taxa)
      results = []
      (1..MAX_PAGES).each do |page|
        batch = fetch_page(taxa, page)
        results.concat(batch)
        return results if batch.size < PAGE_SIZE

        note_overflow(page) if page == MAX_PAGES
      end
      results
    end

    def fetch_page(taxa, page)
      query = { taxon_id: taxa.join(","), updated_since: @since.utc.iso8601,
                order_by: "updated_at", order: "asc",
                per_page: PAGE_SIZE, page: page }.to_query
      Array(fetch_json("observations?#{query}")&.dig("results"))
    end

    def note_overflow(page)
      @warnings << "iNat alert poll stopped at #{page} pages of " \
                   "#{PAGE_SIZE}; the rest waits for the next cycle."
    end
  end
end
