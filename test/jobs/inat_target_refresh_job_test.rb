# frozen_string_literal: true

require("test_helper")

# Re-confirming saved iNat target lookups, and following a taxon
# iNaturalist has swapped.
class InatTargetRefreshJobTest < ActiveJob::TestCase
  include InatStubHelpers

  SWAPPED = 351_380
  REPLACEMENT = 1_525_548

  def setup
    super
    @project = projects(:rare_fungi_project)
    @name = names(:coprinus_comatus)
    @other = names(:agaricus_campestris)
    @location = locations(:burbank)
    stub_request(:get, inat_api_matcher("places")).
      to_return(status: 200, body: { results: [] }.to_json)
  end

  # ---- re-confirming -----------------------------------------------------

  def test_a_taxon_still_current_only_has_its_time_moved
    row = stale_row(@name, SWAPPED)
    stub_taxon_record(SWAPPED, is_active: true)

    InatTargetRefreshJob.perform_now

    row.reload

    assert_equal(SWAPPED, row.inat_id, "the id should be left as it is")
    assert_operator(row.checked_at, :>, 1.hour.ago)
  end

  def test_a_lookup_confirmed_today_is_not_asked_again
    row = InatTargetLookup.record(
      @name, SWAPPED, version: Inat::TargetSearch::TAXON_MATCHING_VERSION
    )

    InatTargetRefreshJob.perform_now

    assert_equal(row.checked_at.to_i, row.reload.checked_at.to_i)
    assert_not_requested(:get, inat_api_matcher("taxa/#{SWAPPED}"))
  end

  # ---- following a swap --------------------------------------------------

  def test_a_swapped_taxon_moves_to_its_replacement
    row = stale_row(@name, SWAPPED)
    stub_swap

    InatTargetRefreshJob.perform_now

    assert_equal(REPLACEMENT, row.reload.inat_id)
  end

  def test_the_replacement_name_joins_the_project_beside_the_old_one
    stale_row(@name, SWAPPED)
    stub_swap

    InatTargetRefreshJob.perform_now

    adopted = Name.find_by(text_name: "Collybia nuda")

    assert_not_nil(adopted, "the replacement's name should have been created")
    assert_includes(@project.reload.target_names, adopted)
    assert_includes(@project.target_names, @name,
                    "the spelling a coordinator entered should stay")
  end

  # A split leaves no single answer to adopt.
  def test_a_split_taxon_becomes_a_miss
    row = stale_row(@name, SWAPPED)
    stub_taxon_record(SWAPPED, is_active: false,
                               current_synonymous_taxon_ids: [111, 222])

    InatTargetRefreshJob.perform_now

    assert_nil(row.reload.inat_id)
    assert_not_includes(@project.reload.target_names.map(&:text_name),
                        "Collybia nuda")
  end

  def test_a_replacement_with_no_usable_name_is_reported_and_the_id_saved
    row = stale_row(@name, SWAPPED)
    stub_taxon_record(SWAPPED, is_active: false,
                               current_synonymous_taxon_ids: [REPLACEMENT])
    stub_request(:get, inat_api_matcher("taxa/#{REPLACEMENT}")).
      to_return(status: 200, body: { results: [] }.to_json)

    InatTargetRefreshJob.perform_now

    assert_equal(REPLACEMENT, row.reload.inat_id,
                 "the id is the half that fixes the poll")
  end

  # ---- re-asking a miss --------------------------------------------------

  # Saved answers have no expiry, so a miss would stand for good
  # without this.
  def test_a_miss_is_asked_again_by_name
    row = stale_row(@name, false)
    stub_name_search(@name.text_name, 47_347)

    InatTargetRefreshJob.perform_now

    assert_equal(47_347, row.reload.inat_id)
  end

  # ---- the window the back-scan reopens ----------------------------------

  def test_a_swap_scans_back_to_when_the_row_was_last_confirmed
    since = 3.days.ago
    row = stale_row(@name, SWAPPED)
    row.update_column(:checked_at, since)
    stub_swap
    start_alerting
    stub_observations

    InatTargetRefreshJob.perform_now

    assert_requested(:get, inat_api_matcher("observations")) do |request|
      query = Rack::Utils.parse_query(URI(request.uri).query)
      query["taxon_id"] == REPLACEMENT.to_s &&
        Time.iso8601(query["updated_since"]).to_i == since.to_i
    end
  end

  # ---- housekeeping ------------------------------------------------------

  def test_a_row_whose_target_is_gone_is_dropped
    row = stale_row(@name, SWAPPED)
    row.update_columns(target_id: 0)

    InatTargetRefreshJob.perform_now

    assert_not(InatTargetLookup.exists?(row.id))
  end

  def test_a_refusal_stops_the_run_and_leaves_the_rest
    first = stale_row(@name, SWAPPED)
    second = stale_row(@other, 48_701)
    [first, second].each_with_index do |row, index|
      row.update_column(:checked_at, (index + 2).days.ago)
    end
    stub_request(:get, inat_api_matcher("taxa")).to_return(status: 429)

    InatTargetRefreshJob.perform_now

    assert_equal(SWAPPED, first.reload.inat_id)
    assert_equal(48_701, second.reload.inat_id)
    assert_operator(first.checked_at, :<, 1.day.ago,
                    "a refused row keeps its place in the staleness order")
  end

  def test_the_job_runs_on_the_paced_lookup_queue
    assert_enqueued_with(job: InatTargetRefreshJob, queue: "inat_lookups") do
      InatTargetRefreshJob.perform_later
    end
  end

  private

  def stale_row(target, answer)
    row = InatTargetLookup.record(
      target, answer, version: Inat::TargetSearch.matching_version(target)
    )
    row.update_column(:checked_at, 2.days.ago)
    row
  end

  def stub_swap
    stub_taxon_record(SWAPPED, is_active: false,
                               current_synonymous_taxon_ids: [REPLACEMENT])
    stub_taxon_record(REPLACEMENT, is_active: true, name: "Collybia nuda")
  end

  # One taxon as `GET /taxa/:id` returns it.
  def stub_taxon_record(inat_id, **attributes)
    taxon = { id: inat_id, name: "Lepista nuda", rank: "species",
              ancestor_ids: [Inat::Constants::FUNGI_TAXON_ID, inat_id] }.
            merge(attributes)
    stub_request(:get, inat_api_matcher("taxa/#{inat_id}")).
      to_return(status: 200, body: { results: [taxon] }.to_json)
  end

  def stub_name_search(text_name, inat_id)
    stub_request(
      :get,
      "#{Inat::Constants::API_BASE}/taxa?q=#{ERB::Util.url_encode(text_name)}" \
      "&per_page=5"
    ).to_return(status: 200,
                body: { results: [fungal_taxon(inat_id, text_name)] }.to_json)
  end

  # The back-scan reaches iNat only for a project that alerts, which
  # needs a site row, recipients, and a watermark.
  def start_alerting
    @project.update!(alert_recipient_ids: [users(:rolf).id])
    ProjectExternalSite.create!(project: @project,
                                external_site: external_sites(:inaturalist),
                                use_constraints: true)
    external_sites(:inaturalist).
      update_column(:last_alert_poll_at, 1.hour.ago)
  end

  def stub_observations
    stub_request(:get, inat_api_matcher("observations")).
      to_return(status: 200,
                body: { total_results: 0, results: [] }.to_json)
  end
end
