# frozen_string_literal: true

class Inat
  # Scheduled daily refresh of the read-only reflections due for sync
  # (#4215): the same per-reflection resync as the "Sync now" button
  # (Inat::ReflectionResync), driven over the whole reflection population
  # instead of one occurrence, and with no Turbo broadcast -- nobody is
  # watching a scheduled run. iNat ids are chunked to the fetcher's
  # per-call maximum, so a run is a handful of API calls rather than one
  # per reflection.
  #
  # "Due" is a reflection whose iNat link was last synced longer ago than
  # RESYNC_INTERVAL (or never). The interval sits just under a day so a
  # daily run always re-qualifies a reflection while skipping one a user
  # just refreshed by hand. Oldest-synced first, so a run cut short still
  # makes progress on the stalest.
  class ReflectionBatchResyncer
    RESYNC_INTERVAL = 20.hours
    # iNat returns at most PAGE_SIZE results for one id-list query, so a
    # larger chunk would silently drop the overflow.
    CHUNK_SIZE = ObsFetcher::PAGE_SIZE

    def initialize(fetcher: ObsFetcher.new, applier: ReflectionResync.new)
      @fetcher = fetcher
      @applier = applier
    end

    # Runs the batch and returns a status => count Hash across every
    # reflection processed (empty when iNaturalist isn't configured or
    # nothing is due).
    def resync_all
      site = ExternalSite.find_by(name: ExternalSite::INATURALIST_NAME)
      return {} unless site

      counts = Hash.new(0)
      due_reflections(site).each_slice(CHUNK_SIZE).with_index do |chunk, i|
        # Pace chunks to iNat's ~1 req/sec guidance -- the fetcher paces
        # only its own paginating callers, not one call per chunk here.
        # No wait before the first chunk.
        sleep(ObsFetcher::INTER_PAGE_SLEEP) if i.positive?
        tally_chunk(chunk, counts)
      end
      # Only advance the source watermark on a clean run: a transient
      # fetch failure leaves its reflections still due (their per-link
      # last_synced_at is untouched), so the source isn't fully synced.
      site.update!(last_successful_sync_at: Time.zone.now) unless
        counts[:fetch_failed].positive?
      counts
    end

    private

    def tally_chunk(chunk, counts)
      by_id, failed = @fetcher.fetch_batch(
        chunk.map { |reflection| ReflectionResync.inat_id(reflection) }
      )
      chunk.each do |reflection|
        result = @applier.call(reflection, by_id, failed)
        counts[result.status] += 1
      end
    end

    # Read-only reflections whose iNat import link is due for a refresh.
    # external_links is preloaded so the per-reflection import_link /
    # external_site reads the applier makes don't each hit the database.
    def due_reflections(site)
      last_synced = ExternalLink[:last_synced_at]
      Observation.where.not(reflected_at: nil).
        joins(:external_links).merge(ExternalLink.import).
        where(external_links: { external_site_id: site.id }).
        where(last_synced.eq(nil).or(last_synced.lt(RESYNC_INTERVAL.ago))).
        order(last_synced.asc).
        preload(external_links: :external_site)
    end
  end
end
