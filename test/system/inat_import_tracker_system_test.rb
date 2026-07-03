# frozen_string_literal: true

require("application_system_test_case")
require_relative("../jobs/inat_import_job_test_doubles")

# Regression coverage for the "tracker keeps ticking forever" bug: the
# status panel's Stimulus controller (app/javascript/controllers/
# inat-import_controller.js) must still reach "Done" even when every
# single Turbo Stream broadcast for an import is missed — the failure mode
# behind the original report, where a fast import finished without the
# browser ever receiving a live update. Turbo::StreamsChannel is stubbed to
# a no-op for the whole import so the browser can *only* learn the true
# state via the controller's periodic catch-up poll, never via broadcast.
#
# The mock iNat response also carries one observation with no observed-on
# date (as in the original report), so the run exercises the same
# ignored-obs bookkeeping that was part of the original bug report.
class InatImportTrackerSystemTest < ApplicationSystemTestCase
  include InatImportJobTestDoubles

  def setup
    super
    @previous_adapter = ActiveJob::Base.queue_adapter
    # perform_later must actually execute the job on a background thread
    # while the browser is watching the page, the way a real SolidQueue
    # worker would. The suite's default :test adapter only records the
    # job; it never runs it.
    ActiveJob::Base.queue_adapter = :async
  end

  def teardown
    ActiveJob::Base.queue_adapter = @previous_adapter
    super
  end

  def test_tracker_reaches_done_when_broadcasts_are_missed
    user = users(:rolf)
    strip_date_from_first_result
    # Already "Importing" (not the pre-authorization "Authorizing" state) so
    # the very first page load is guaranteed to render the ticking, not-Done
    # panel — the job is started separately, below, only once that's on
    # screen. That removes any dependence on how long the page itself takes
    # to boot (Puma/asset warm-up on the first request of the run), which
    # would otherwise make this flaky: the job could finish before the
    # first page response is even generated.
    @inat_import = build_pending_inat_import(user: user, state: "Importing",
                                             token: "MockCode")

    stub_inat_interactions
    # Keep the job mid-import for a few seconds after the page is already
    # on screen, so this deterministically exercises the same timing the
    # bug report hit: a catch-up fetch that lands before the job is Done
    # only proves the panel isn't stuck yet — it doesn't prove the panel
    # will ever reach Done.
    delay_observation_response(seconds: 3)
    login!(user)

    Turbo::StreamsChannel.stub(:broadcast_replace_to, nil) do
      visit(inat_import_path(@inat_import))
      assert_selector("[data-inat-import-status-value='Importing']")

      InatImportJob.perform_later(@inat_import)

      using_wait_time(15) do
        assert_selector("[data-inat-import-status-value='Done']")
      end
    end

    @inat_import.reload
    assert_equal("Done", @inat_import.state)
    assert_equal(1, @inat_import.ignored_date_missing_count,
                 "Obs with no observed-on date should be skipped, not imported")
    assert_equal(1, @inat_import.imported_count,
                 "The other obs in the mock response should still import")
  end

  private

  # Overrides the observation-search stub registered by
  # stub_inat_interactions with a slow one (WebMock uses the most recently
  # registered stub that matches). Keeps the job running for a few seconds
  # after the page — already showing "Importing" — is on screen, so the
  # test can exercise the poll actually recovering a Done that arrives with
  # no broadcast, rather than the job racing to finish before the page
  # even renders.
  def delay_observation_response(seconds:)
    stub_request(:get, %r{#{Regexp.escape(API_BASE)}/observations}o).
      with(headers: { "Authorization" => "Bearer MockJWT" }).
      to_return do |_request|
        sleep(seconds)
        { status: 200, body: @mock_inat_response, headers: {} }
      end
  end

  # Mutates @mock_inat_response / @parsed_results so the first result in
  # test/inat/listed_ids.txt (2 observations) has no observed-on date,
  # mirroring the missing-date observation from the original bug report.
  def strip_date_from_first_result
    raw = File.read("test/inat/listed_ids.txt")
    parsed = JSON.parse(raw)
    parsed["results"].first.
      keys.select { |k| k.start_with?("observed_on") }.
      each { |k| parsed["results"].first.delete(k) }
    @mock_inat_response = parsed.to_json
    @parsed_results = parsed["results"]
  end

  def build_pending_inat_import(user:, state:, token:)
    InatImport.create!(
      user: user,
      state: state,
      inat_ids: @parsed_results.pluck("id").join(","),
      inat_username: @parsed_results.first["user"]["login"],
      importables: @parsed_results.length,
      total_importables: @parsed_results.length,
      imported_count: 0,
      avg_import_time: InatImport::BASE_AVG_IMPORT_SECONDS,
      response_errors: "",
      token: token,
      log: [],
      started_at: Time.zone.now,
      ended_at: nil,
      cancel: false
    )
  end
end
