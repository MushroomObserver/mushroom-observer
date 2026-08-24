# frozen_string_literal: true

class Inat
  # Scheduled daily refresh of the read-only reflections (#4215): the
  # same per-reflection resync as the "Sync now" button
  # (Inat::ReflectionResync), driven over the whole reflection population.
  #
  # Incremental by iNaturalist's `updated_since`: each run fetches only the
  # reflections whose source changed since the last clean run (the source
  # watermark, external_sites.last_successful_sync_at), so the work scales
  # with how much changed rather than the population size. The first run
  # (no watermark) is a full reconciliation.
  #
  # Because an incremental fetch returns only changed ids, a missing id
  # means "unchanged", not "deleted" -- so this job does not detect a
  # source deleted on iNat. That stays the "Sync now" button's job (it
  # does a full fetch), which is enough while a vanished source only logs
  # the loss; a scheduled deletion sweep can be added when it needs to do
  # more.
  #
  # iNat ids are chunked to the fetcher's per-call maximum and paced, so a
  # run is a handful of API calls rather than one per reflection. No Turbo
  # broadcast -- a scheduled run has no viewer.
  class ReflectionBatchResyncer
    # iNat returns at most PAGE_SIZE results for one id-list query, so a
    # larger chunk would silently drop the overflow.
    CHUNK_SIZE = ObsFetcher::PAGE_SIZE

    def initialize(fetcher: ObsFetcher.new, applier: ReflectionResync.new)
      @fetcher = fetcher
      @applier = applier
    end

    # Runs the batch and returns a status => count Hash across every
    # reflection processed (empty when iNaturalist isn't configured).
    def resync_all
      site = ExternalSite.find_by(name: ExternalSite::INATURALIST_NAME)
      return {} unless site

      since = site.last_successful_sync_at
      # Stamp the watermark from BEFORE the fetch, so anything changed
      # while this run was in flight is re-caught next time (re-applying
      # unchanged data is a no-op).
      started_at = Time.zone.now
      counts = tally_all(reflections(site), since)
      advance_watermark(site, started_at, counts)
      counts
    end

    private

    def tally_all(reflections, since)
      counts = Hash.new(0)
      reflections.each_slice(CHUNK_SIZE).with_index do |chunk, i|
        # Pace chunks to iNat's ~1 req/sec guidance -- the fetcher paces
        # only its own paginating callers, not one call per chunk here.
        # No wait before the first chunk.
        sleep(ObsFetcher::INTER_PAGE_SLEEP) if i.positive?
        tally_chunk(chunk, counts, since)
      end
      counts
    end

    def tally_chunk(chunk, counts, since)
      by_id, failed = @fetcher.fetch_batch(
        chunk.map { |reflection| ReflectionResync.inat_id(reflection) },
        updated_since: since
      )
      chunk.each do |reflection|
        result = @applier.call(reflection, by_id, failed, absent: :unchanged)
        counts[result.status] += 1
      end
    end

    # Advance the source watermark only on a clean run: a transient fetch
    # failure leaves its window unsynced, so the next run must re-cover it.
    def advance_watermark(site, started_at, counts)
      return if counts[:fetch_failed].positive?

      site.update!(last_successful_sync_at: started_at)
    end

    # Every read-only iNat reflection. `updated_since` narrows the fetch
    # server-side, so there's no per-reflection due filter here.
    # external_links is preloaded so the per-reflection import_link /
    # external_site reads the applier makes don't each hit the database.
    def reflections(site)
      Observation.where.not(reflected_at: nil).
        joins(:external_links).merge(ExternalLink.import).
        where(external_links: { external_site_id: site.id }).
        order(:id).
        preload(external_links: :external_site)
    end
  end
end
