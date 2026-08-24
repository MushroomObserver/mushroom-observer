# frozen_string_literal: true

class Inat
  # Batched, public, rate-limited fetch of current iNat observations by id,
  # with retry/backoff and a descriptive User-Agent. `fetch_batch` returns
  # [results_by_id, failed?]; failed? is true when the batch exhausted its
  # retries, so callers can distinguish a transient fetch failure from an
  # observation genuinely absent/deleted on iNat.
  #
  # Shared bulk-fetch infrastructure: the import audit (#4213) and the
  # reflection-resolution extract builder (#4585) both consume it.
  class ObsFetcher
    PAGE_SIZE = 200          # iNat's maximum per_page
    INTER_PAGE_SLEEP = 1     # ~1 req/sec; within iNat's ~60/min guidance
    MAX_RETRIES = 3          # per batch, on 429/5xx/timeout
    RETRY_BASE_SLEEP = 2     # seconds; doubles each retry (2, 4, 8)
    USER_AGENT =
      "MushroomObserver bulk fetch (+https://mushroomobserver.org)"

    # Transient errors worth retrying with backoff before giving up.
    RETRYABLE_ERRORS = [
      RestClient::TooManyRequests, RestClient::ServiceUnavailable,
      RestClient::BadGateway, RestClient::GatewayTimeout,
      RestClient::RequestTimeout, RestClient::ServerBrokeConnection,
      Errno::ECONNRESET, SocketError
    ].freeze

    # Raised when a batch can't be fetched after MAX_RETRIES.
    class FetchError < StandardError; end

    # Fetch one batch of up to PAGE_SIZE external ids. Returns
    # [results_by_id, failed?] - failed? is true when the batch exhausted its
    # retries, so the caller can mark those obs "fetch_error" vs "not_found".
    # `updated_since` (a Time) narrows the batch to ids changed on iNat
    # since then, so an incremental sync fetches only what moved. Left
    # nil, the batch returns every id -- and only then does an id missing
    # from the results mean "deleted on iNat" rather than "unchanged".
    def fetch_batch(external_ids, updated_since: nil)
      ids = external_ids.compact.uniq
      # An empty id list would query iNat with no `id` filter (i.e. every
      # observation), so short-circuit to an empty (non-failed) result.
      return [{}, false] if ids.empty?

      by_id = {}
      fetch_page(ids, updated_since: updated_since).each do |raw|
        by_id[raw[:id].to_s] = raw
      end
      [by_id, false]
    rescue FetchError
      [{}, true]
    end

    private

    def fetch_page(ids, updated_since: nil, attempt: 1)
      response = get("observations?#{page_query(ids, updated_since)}")
      JSON.parse(response.body, symbolize_names: true)[:results] || []
    rescue *RETRYABLE_ERRORS, JSON::ParserError => e
      raise(FetchError.new(e.message)) if attempt > MAX_RETRIES

      backoff_for_retry(e, ids, attempt)
      fetch_page(ids, updated_since: updated_since, attempt: attempt + 1)
    end

    def backoff_for_retry(error, ids, attempt)
      backoff = RETRY_BASE_SLEEP * (2**(attempt - 1))
      warn("  iNat #{error.class} on #{ids.size} ids; " \
           "retry #{attempt}/#{MAX_RETRIES} in #{backoff}s")
      sleep(backoff)
    end

    def page_query(ids, updated_since = nil)
      query = { id: ids.join(","), per_page: PAGE_SIZE,
                order_by: "id", order: "asc" }
      query[:updated_since] = updated_since.utc.iso8601 if updated_since
      query.to_query
    end

    def get(path)
      Inat::APIRequest.new(nil).
        request(path: path, headers: { user_agent: USER_AGENT })
    end
  end
end
