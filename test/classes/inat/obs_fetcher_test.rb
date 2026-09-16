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

  def test_fetch_batch_narrows_by_updated_since_when_given
    since = Time.utc(2026, 8, 1, 12, 0, 0)
    stub_request(:get, obs_url_since("1", since)).
      to_return(status: 200, body: { results: [{ id: 1 }] }.to_json)

    by_id, failed = Inat::ObsFetcher.new.fetch_batch(%w[1],
                                                     updated_since: since)

    assert_not(failed)
    assert_equal(%w[1], by_id.keys)
  end

  def test_fetch_batch_with_no_ids_makes_no_request
    # No WebMock stub -- if a request went out, WebMock would raise.
    by_id, failed = Inat::ObsFetcher.new.fetch_batch([nil])

    assert_not(failed)
    assert_empty(by_id)
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

  def test_field_present_appends_the_inat_field_filter
    fetcher = Inat::ObsFetcher.new
    with_field = fetcher.send(:page_query, %w[1 2], nil,
                              "Mushroom Observer URL")

    assert_includes(with_field, "field:Mushroom%20Observer%20URL",
                    "the field: filter is appended raw (colon unescaped)")
    assert_not(fetcher.send(:page_query, %w[1 2], nil, nil).include?("field:"),
               "no field filter when none is given")
  end

  private

  def obs_url(ids)
    query = { id: ids, per_page: 200,
              order_by: "id", order: "asc" }.to_query
    "#{API_BASE}/observations?#{query}"
  end

  def obs_url_since(ids, since)
    query = { id: ids, per_page: 200, order_by: "id", order: "asc",
              updated_since: since.utc.iso8601 }.to_query
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
