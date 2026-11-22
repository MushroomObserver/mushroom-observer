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
    # Ids per request when re-reading observations that have left the
    # taxon filter, which iNat answers by id list.
    ID_CHUNK = 200
    # How far back that id list reaches. Only the size of that one
    # request depends on it, and a find nobody has touched in half a
    # year is not what a coordinator is waiting on.
    ALERT_LOOKBACK = 180.days

    attr_reader :alerts_sent, :warnings

    # `page_size` and `max_pages` are arguments rather than constants
    # read directly so a test can drive the overflow path without
    # fabricating a thousand results.
    def initialize(site: ExternalSite.inaturalist, page_size: PAGE_SIZE,
                   max_pages: MAX_PAGES)
      @site = site
      @page_size = page_size
      @max_pages = max_pages
      @alerts_sent = 0
      @warnings = []
      @overflowed = false
      @fetch_failed = false
    end

    # A Hash of User => Array of ProjectAlert, the digest
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

      candidates = fetch_candidates(criteria)
      candidates += fetch_departed(criteria, candidates)
      digests = collect(criteria, candidates)
      advance_watermark(candidates)
      digests
    end

    private

    # The first cycle for a site establishes where the poll starts and
    # sends nothing.
    def seed_watermark
      stamp(@polled_at)
      {}
    end

    # Only a clean poll moves the watermark. A fetch that failed leaves
    # its window unread, and stamping over it would drop whatever was
    # identified during it -- the rare find this cycle exists to catch.
    # The next cycle re-covers the window instead.
    def advance_watermark(candidates)
      return if @fetch_failed

      stamp(watermark_after(candidates))
    end

    # update_column so stamping this bookkeeping timestamp isn't blocked
    # by validating unrelated (possibly already invalid) fields on the
    # site, matching the sibling watermark on the same table.
    def stamp(time)
      @site.update_column(:last_alert_poll_at, time)
    end

    def collect(criteria, candidates)
      digests = Hash.new { |hash, user| hash[user] = [] }
      candidates.each do |candidate|
        criteria.each do |criterion|
          alert = alert_for(criterion, candidate)
          next unless alert

          @alerts_sent += 1
          criterion.recipients.each { |user| digests[user] << alert }
        end
      end
      digests
    end

    def alert_for(criterion, candidate)
      return nil unless criterion.matches?(candidate)
      return find_alert(criterion, candidate) unless
        told?(criterion, candidate)

      activity_alert(criterion, candidate)
    end

    # A project hears about a find only under a name it watches.
    def find_alert(criterion, candidate)
      identification = criterion.alertable_identification(candidate)
      return nil unless identification

      record(criterion, candidate, identification,
             criterion.target_name_for(identification))
    end

    # Once a project has been told about an observation, the newest
    # identification is news whatever it names: a temporary code
    # applied to a find is what the coordinators confirm by hand, and
    # it is reported whether or not the community taxon follows it.
    # The message stays grouped under the watched name the project
    # was told, which is where a coordinator looks for it.
    def activity_alert(criterion, candidate)
      identification = criterion.activity_identification(candidate)
      return nil unless identification

      record(criterion, candidate, identification,
             told_target_name(criterion, candidate))
    end

    def record(criterion, candidate, identification, target_name)
      return nil if target_name.blank?

      ProjectAlert.record(
        project: criterion.project, external_site: @site,
        identification: identification, observation: candidate.to_h,
        target_name: target_name
      )
    end

    def told_rows(criterion, candidate)
      ProjectAlert.where(project: criterion.project, external_site: @site,
                         remote_observation_id: candidate.id)
    end

    def told?(criterion, candidate)
      told_rows(criterion, candidate).exists?
    end

    def told_target_name(criterion, candidate)
      told_rows(criterion, candidate).order(:id).last&.target_name
    end

    # An identification that moves the community taxon off a watched
    # name takes its observation out of the poll's filter, so the
    # naming the coordinators asked to hear about is invisible to it.
    # The ids this site has alerted are a query rather than new
    # state; whatever the poll already returned is dropped.
    def fetch_departed(criteria, returned)
      return [] if @fetch_failed

      ids = departed_ids(criteria, returned)
      return [] if ids.empty?

      ids.each_slice(ID_CHUNK).flat_map { |chunk| fetch_chunk(chunk) }
    end

    def fetch_chunk(ids)
      query = { id: ids.join(","), per_page: ids.size }.to_query
      json = fetch_json("observations?#{query}")
      return note_departed_failure if json.nil?

      Array(json["results"]).map { |result| Inat::AlertCandidate.new(result) }
    end

    # A failure here costs nothing but a cycle: these ids are read
    # again next time, and the watermark covers the poll, not this.
    def note_departed_failure
      @warnings << "iNat re-read of already-alerted observations " \
                   "failed; they are read again next cycle."
      []
    end

    def departed_ids(criteria, returned)
      ProjectAlert.where(project: criteria.map(&:project),
                         external_site: @site,
                         alerted_at: ALERT_LOOKBACK.ago..).
        distinct.pluck(:remote_observation_id).compact.uniq -
        returned.map(&:id)
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
      (1..@max_pages).each do |page|
        batch = fetch_page(taxa, page)
        return note_fetch_failure(page, results) if batch.nil?

        results.concat(batch)
        return results if batch.size < @page_size

        note_overflow(page) if page == @max_pages
      end
      results
    end

    # nil when iNat could not answer, which a page of no results would
    # otherwise be indistinguishable from.
    def fetch_page(taxa, page)
      query = { taxon_id: taxa.join(","), updated_since: @since.utc.iso8601,
                order_by: "updated_at", order: "asc",
                per_page: @page_size, page: page }.to_query
      json = fetch_json("observations?#{query}")
      return nil if json.nil?

      Array(json["results"])
    end

    # Whatever earlier pages did return is still worth matching -- the
    # alert row decides whether a project has been told, so re-reading
    # those observations next cycle costs nothing.
    def note_fetch_failure(page, results)
      @fetch_failed = true
      @warnings << "iNat alert poll failed at page #{page}; its window " \
                   "stays open for the next cycle."
      results
    end

    def note_overflow(page)
      @overflowed = true
      @warnings << "iNat alert poll stopped at #{page} pages of " \
                   "#{@page_size}; the rest waits for the next cycle."
    end

    # Where the next cycle starts. Ordinarily the moment this one
    # began, so anything touched while it ran is caught next time. When
    # the poll stopped at its page ceiling, the newest observation it
    # did read instead -- stamping the later moment would step over
    # the pages it had not reached and drop them. An observation read
    # twice is harmless: the alert row is what decides whether a
    # project has been told.
    def watermark_after(candidates)
      return @polled_at unless @overflowed

      candidates.filter_map(&:updated_at).max || @polled_at
    end
  end
end
