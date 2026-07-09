# frozen_string_literal: true

require("test_helper")

# Tests batching + retry behaviour with WebMock-stubbed iNat responses.
class Inat::ObsFetcherTest < UnitTestCase
  include Inat::Constants

  def test_fetch_batch_indexes_results_by_id
    stub_obs("1,2", [{ id: 1 }, { id: 2 }])
    by_id, failed = Inat::ObsFetcher.new.fetch_batch(%w[1 2])

    assert_not(failed)
    assert_equal(%w[1 2], by_id.keys)
    assert_equal(1, by_id["1"][:id])
  end

  def test_fetch_batch_reports_failure_after_exhausting_retries
    stub_obs_status("1", 429) # TooManyRequests is retryable
    fetcher = Inat::ObsFetcher.new
    fetcher.define_singleton_method(:sleep) { |*| } # skip backoff waits
    fetcher.define_singleton_method(:warn) { |*| }  # quiet retry logging

    by_id, failed = fetcher.fetch_batch(%w[1])

    assert(failed)
    assert_empty(by_id)
  end

  private

  def obs_url(ids)
    query = { id: ids, per_page: 200,
              order_by: "id", order: "asc" }.to_query
    "#{API_BASE}/observations?#{query}"
  end

  def stub_obs(ids, results)
    stub_request(:get, obs_url(ids)).
      to_return(status: 200, body: { results: results }.to_json, headers: {})
  end

  def stub_obs_status(ids, status)
    stub_request(:get, obs_url(ids)).to_return(status: status)
  end
end
