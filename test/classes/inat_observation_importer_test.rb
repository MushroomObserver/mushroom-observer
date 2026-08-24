# frozen_string_literal: true

require("test_helper")

class InatObservationImporterTest < UnitTestCase
  include Inat::Constants

  # update_timings keeps a cumulative moving average (CMA) of per-observation
  # import time for the current job. After obs #1 with elapsed T: avg = T.
  # After obs #2 with elapsed S: avg = (T + S) / 2.
  def test_update_timings_cumulative_moving_average
    import = inat_imports(:rolf_inat_import)
    importer = ::Inat::ObservationImporter.new(import, import.user)

    # Simulate first obs taking ~10 seconds
    import.update(avg_import_time: 15.0, imported_count: 1,
                  last_obs_start: 10.seconds.ago)
    importer.send(:update_timings)
    import.reload
    assert_in_delta(10, import.avg_import_time, 1,
                    "After first obs, avg_import_time should equal elapsed " \
                    "time (CMA with count=1 collapses to the raw value)")

    # Simulate second obs taking ~20 seconds; mean of [10, 20] = 15
    import.update(imported_count: 2, last_obs_start: 20.seconds.ago)
    importer.send(:update_timings)
    import.reload
    assert_in_delta(15, import.avg_import_time, 1,
                    "After second obs, avg_import_time should be the mean " \
                    "of both elapsed times")
  end

  # accumulate_counts also threads a builder's created_image_ids up onto
  # the importer -- InatImportJob reads this after each batch to enqueue
  # one TransferImagesJob per batch (see #4791's target design).
  def test_accumulate_counts_collects_created_image_ids
    import = inat_imports(:rolf_inat_import)
    importer = ::Inat::ObservationImporter.new(import, import.user)
    fake_builder = Object.new
    fake_builder.define_singleton_method(:unlicensed_obs) { 0 }
    fake_builder.define_singleton_method(:skipped_images) { 0 }
    fake_builder.define_singleton_method(:created_image_ids) { [123, 456] }

    importer.send(:accumulate_counts, fake_builder)

    assert_equal([123, 456], importer.image_ids)
  end

  def test_canceled
    import = inat_imports(:ollie_inat_import)
    assert(import.canceled?, "Test needs a canceled InatImport fixture")
    user = import.user
    mock_inat_response = File.read("test/inat/calostoma_lutescens.txt")
    page = JSON.parse(mock_inat_response)

    importer = ::Inat::ObservationImporter.new(import, user)
    assert_no_difference(
      "Observation.count",
      "ObservationImporter should stop importing observations after " \
      "user cancels the Import"
    ) do
      importer.import_page(page)
    end
  end

  def test_reached_import_cap
    import = inat_imports(:rolf_inat_import)
    import.update_columns(imported_count: InatImport::MAX_IMPORTABLE)
    user = import.user
    mock_inat_response = File.read("test/inat/calostoma_lutescens.txt")
    page = JSON.parse(mock_inat_response)

    importer = ::Inat::ObservationImporter.new(import, user)
    assert_no_difference(
      "Observation.count",
      "ObservationImporter should stop importing once MAX_IMPORTABLE " \
      "is reached, even within a single page"
    ) do
      importer.import_page(page)
    end
  end

  # ---------- update_inat_observation_field: 503 writeback retry (#4589) ----

  def test_writeback_ignores_503_when_field_already_written
    importer, args = writeback_call_args
    stub_writeback_post(status: 503)
    stub_writeback_verification_get(args, written: true)

    importer.send(:update_inat_observation_field, **args)

    assert_requested(:post, writeback_post_url, times: 1)
    assert_requested(:get, writeback_get_url(args[:observation_id]),
                     times: 1)
  end

  def test_writeback_retries_503_with_default_backoff_then_succeeds
    importer, args = writeback_call_args
    sleeps = stub_sleep_spy(importer)
    stub_request(:post, writeback_post_url).
      to_return({ status: 503 }, { status: 200 })
    stub_writeback_verification_get(args, written: false)

    importer.send(:update_inat_observation_field, **args)

    assert_requested(:post, writeback_post_url, times: 2)
    assert_equal([2], sleeps,
                 "First retry should use the default doubling backoff " \
                 "when iNat sends no Retry-After header")
  end

  def test_writeback_honors_retry_after_within_budget
    importer, args = writeback_call_args
    sleeps = stub_sleep_spy(importer)
    stub_request(:post, writeback_post_url).
      to_return({ status: 503, headers: { "Retry-After" => "3" } },
                { status: 200 })
    stub_writeback_verification_get(args, written: false)

    importer.send(:update_inat_observation_field, **args)

    assert_equal([3], sleeps,
                 "Should sleep iNat's Retry-After value when it's " \
                 "within the retry budget, instead of the doubling default")
  end

  def test_writeback_ignores_retry_after_over_budget
    importer, args = writeback_call_args
    sleeps = stub_sleep_spy(importer)
    stub_request(:post, writeback_post_url).
      to_return({ status: 503, headers: { "Retry-After" => "30" } },
                { status: 200 })
    stub_writeback_verification_get(args, written: false)

    importer.send(:update_inat_observation_field, **args)

    assert_equal([2], sleeps,
                 "A Retry-After above the retry budget should be " \
                 "ignored in favor of the doubling default")
  end

  def test_writeback_raises_after_exhausting_retries
    importer, args = writeback_call_args
    sleeps = stub_sleep_spy(importer)
    stub_writeback_post(status: 503)
    stub_writeback_verification_get(args, written: false)

    assert_raises(RestClient::ServiceUnavailable,
                  "Should give up and raise once retries are exhausted " \
                  "and the field is still unconfirmed") do
      importer.send(:update_inat_observation_field, **args)
    end

    assert_requested(
      :post, writeback_post_url,
      times: ::Inat::ObservationImporter::MAX_WRITEBACK_RETRIES + 1
    )
    assert_equal([2, 4, 8], sleeps,
                 "Should back off 2s/4s/8s across the 3 retries")
  end

  def test_writeback_treats_failed_verification_as_unconfirmed
    importer, args = writeback_call_args
    sleeps = stub_sleep_spy(importer)
    stub_request(:post, writeback_post_url).
      to_return({ status: 503 }, { status: 200 })
    stub_request(:get, writeback_get_url(args[:observation_id])).
      to_return(status: 500)

    importer.send(:update_inat_observation_field, **args)

    assert_requested(:post, writeback_post_url, times: 2)
    assert_equal([2], sleeps,
                 "A failed verification GET should be treated as " \
                 "unconfirmed and fall through to a normal retry")
  end

  def test_writeback_raises_immediately_on_non_retryable_error
    importer, args = writeback_call_args
    stub_writeback_post(status: 401)

    assert_raises(RestClient::Unauthorized,
                  "Non-retryable errors should raise without retrying " \
                  "or checking iNat for the written field") do
      importer.send(:update_inat_observation_field, **args)
    end

    assert_requested(:post, writeback_post_url, times: 1)
    assert_not_requested(:get, writeback_get_url(args[:observation_id]))
  end

  private

  def writeback_call_args
    import = inat_imports(:rolf_inat_import)
    importer = ::Inat::ObservationImporter.new(import, import.user)
    args = { observation_id: 123, field_id: MO_URL_OBSERVATION_FIELD_ID,
             value: "#{MO.http_domain}/456" }
    [importer, args]
  end

  # Replace `sleep` on the importer instance with a spy that records the
  # requested durations instead of sleeping the test thread.
  def stub_sleep_spy(importer)
    sleeps = []
    importer.define_singleton_method(:sleep) { |secs| sleeps << secs }
    importer.define_singleton_method(:warn) { |*| } # quiet retry logging
    sleeps
  end

  def writeback_post_url
    "#{API_BASE}/observation_field_values"
  end

  def writeback_get_url(observation_id)
    "#{API_BASE}/observations/#{observation_id}"
  end

  def stub_writeback_post(status:)
    stub_request(:post, writeback_post_url).to_return(status: status)
  end

  def stub_writeback_verification_get(args, written:)
    ofvs = written ? [{ field_id: args[:field_id], value: args[:value] }] : []
    body = { results: [{ id: args[:observation_id], ofvs: ofvs }] }.to_json

    stub_request(:get, writeback_get_url(args[:observation_id])).
      to_return(status: 200, body: body)
  end
end
