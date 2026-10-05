# frozen_string_literal: true

require("test_helper")

# The alert half of the iNaturalist cycle (#5416).
class Inat::AlertScannerTest < UnitTestCase
  include InatStubHelpers

  # The rare-fungi fixture is the shape alerting is for: target names
  # and target locations both set.
  def setup
    super
    @project = projects(:rare_fungi_project)
    @site = external_sites(:inaturalist)
    @site.update!(last_alert_poll_at: 1.hour.ago)
    @recipient = users(:mary)
    @coprinus = names(:coprinus_comatus)
    @burbank = locations(:burbank)
    stub_taxon_lookups
    stub_place_lookups
  end

  def stub_taxon_lookups
    stub_request(:get, inat_api_matcher("taxa")).
      to_return(lambda { |request|
        name = CGI.unescape(request.uri.query.to_s[/q=([^&]*)/, 1].to_s)
        { status: 200,
          body: { results: [{ id: taxon_id_for(name), name: name }] }.to_json }
      })
  end

  def taxon_id_for(name)
    name == @coprinus.text_name ? 47_347 : 48_701
  end

  def stub_place_lookups
    geojson = { "coordinates" =>
                [[[@burbank.west, @burbank.south],
                  [@burbank.east, @burbank.north]]] }
    stub_request(:get, inat_api_matcher("places")).
      to_return(status: 200,
                body: { results: [{ id: 962, name: "Burbank",
                                    bounding_box_geojson: geojson }] }.to_json)
  end

  # One observation as iNat returns it, inside Burbank and identified
  # as one of the project's target names.
  def observation(**overrides)
    { "id" => 12_345,
      "observed_on" => "2026-09-20",
      "location" => "#{@burbank.center_lat},#{@burbank.center_lng}",
      "identifications" => [identification] }.merge(overrides.stringify_keys)
  end

  def identification(id: 999, taxon_id: 47_347, current: true)
    { "id" => id, "current" => current,
      "taxon" => { "id" => taxon_id, "name" => "Coprinus comatus" } }
  end

  def stub_observations(results)
    stub_request(:get, inat_api_matcher("observations")).
      to_return(status: 200,
                body: { results: results, total_results: results.size }.to_json)
  end

  # Alerting goes to whoever opted in, so a row that alerts needs at
  # least one recipient.
  def alerting_row(**args)
    args[:alert_recipient_ids] = [@recipient.id] unless
      args.key?(:alert_recipient_ids)
    ProjectExternalSite.create!(project: @project, external_site: @site,
                                use_constraints: true, alerting: true, **args)
  end

  def scan
    Inat::AlertScanner.new(site: @site).scan
  end

  def test_no_alerting_project_asks_inat_nothing
    assert_empty(scan)
    assert_not_requested(:get, inat_api_matcher("observations"))
  end

  # Alerting is opt-in. A row with nobody listed is a row nobody asked
  # for, so a matching observation is recorded and sent to no one.
  def test_a_project_with_no_recipients_sends_nothing
    row = alerting_row
    row.update_column(:alert_recipient_ids, [].to_json)
    stub_observations([observation])

    assert_empty(scan, "Alerting with nobody listed should mail no one")
  end

  def test_a_new_target_identification_alerts_the_recipients
    alerting_row
    stub_observations([observation])

    digests = scan

    assert_equal([@recipient], digests.keys)
    alert = digests.values.first.first

    assert_equal("Coprinus comatus", alert.name)
    assert_equal(Date.parse("2026-09-20"), alert.observed_on)
    assert_equal("12345", alert.remote_observation_id)
  end

  # The row is what says a project has been told, so a later edit to
  # the same observation is not a second alert.
  def test_an_identification_already_alerted_on_is_skipped
    alerting_row
    stub_observations([observation])
    scan

    assert_empty(scan)
    assert_equal(1, ProjectExternalSiteAlert.count)
  end

  # A withdrawn identification comes back with `current` false. An
  # alert is for something urgent to do; a name going away is not.
  def test_a_withdrawn_identification_does_not_alert
    alerting_row
    stub_observations([observation(
      "identifications" => [identification(current: false)]
    )])

    assert_empty(scan)
    assert_equal(0, ProjectExternalSiteAlert.count)
  end

  def test_an_identification_of_an_untracked_taxon_does_not_alert
    alerting_row
    stub_observations([observation(
      "identifications" => [identification(taxon_id: 1234)]
    )])

    assert_empty(scan)
  end

  def test_an_observation_outside_the_target_locations_does_not_alert
    alerting_row
    stub_observations([observation("location" => "10.0,10.0")])

    assert_empty(scan)
  end

  # iNat withholds the point for an obscured observation, and a rare
  # find is the case where an admin most wants to hear.
  def test_an_observation_without_coordinates_alerts
    alerting_row
    stub_observations([observation("location" => nil)])

    assert_equal(1, scan.values.first.size)
  end

  def test_an_observation_outside_the_project_dates_does_not_alert
    @project.update!(start_date: Date.parse("2026-01-01"),
                     end_date: Date.parse("2026-06-30"))
    alerting_row
    stub_observations([observation])

    assert_empty(scan)
  end

  # Switching alerting on is not a request to hear about last year.
  def test_the_first_cycle_seeds_the_watermark_and_sends_nothing
    @site.update!(last_alert_poll_at: nil)
    alerting_row
    stub_observations([observation])

    assert_empty(scan)
    assert_not_nil(@site.reload.last_alert_poll_at)
    assert_not_requested(:get, inat_api_matcher("observations"))
  end

  def test_the_watermark_advances_after_a_cycle
    alerting_row
    stub_observations([])
    before = @site.last_alert_poll_at

    scan

    assert_operator(@site.reload.last_alert_poll_at, :>, before)
  end

  # A target name applied to an observation MO already holds is still
  # news, so the importer's without_field filter has no place here.
  def test_the_poll_does_not_exclude_what_mo_already_holds
    alerting_row
    stub_observations([])
    scan

    assert_requested(:get, inat_api_matcher("observations")) do |request|
      request.uri.query.to_s.exclude?("without_field")
    end
  end

  # A project with no target locations has nothing selective to poll
  # for, so it is left out.
  def test_a_project_without_target_locations_does_not_alert
    @project.project_target_locations.destroy_all
    alerting_row

    assert_empty(scan)
    assert_not_requested(:get, inat_api_matcher("observations"))
  end

  # A project box narrows the target locations further, the way the
  # preview's query does.
  def test_an_observation_outside_the_project_box_does_not_alert
    @project.update!(location: locations(:albion))
    alerting_row
    stub_observations([observation])

    assert_empty(scan)
  end

  def test_an_observation_inside_both_the_box_and_a_target_location_alerts
    @project.update!(location: @burbank)
    alerting_row
    stub_observations([observation])

    assert_equal(1, scan.values.first.size)
  end

  # iNat dates are ISO strings; anything else is no date rather than a
  # broken cycle.
  def test_an_unreadable_date_is_no_date
    alerting_row
    stub_observations([observation("observed_on" => "N/A")])

    alert = scan.values.first.first

    assert_nil(alert.observed_on)
  end

  # A cycle that hits its page ceiling says so instead of walking iNat
  # for a quarter of an hour; what it did not read waits for the next
  # cycle.
  def test_a_poll_that_fills_every_page_reports_the_overflow
    alerting_row
    stub_observations([observation, observation("id" => 12_346)])
    scanner = Inat::AlertScanner.new(site: @site, page_size: 2, max_pages: 2)

    scanner.scan

    assert_equal(1, scanner.warnings.size)
    assert_match(/stopped at 2 pages/, scanner.warnings.first)
  end

  # Stamping the moment the cycle began would step over the pages it
  # did not reach. It resumes from the newest observation it read.
  def test_an_overflowing_poll_resumes_where_it_stopped
    alerting_row
    read = "2026-09-25T00:00:00+00:00"
    stub_observations([observation("updated_at" => read),
                       observation("id" => 12_346, "updated_at" => read)])
    Inat::AlertScanner.new(site: @site, page_size: 2, max_pages: 2).scan

    assert_equal(Time.zone.parse(read), @site.reload.last_alert_poll_at)
  end

  # A failed fetch is not an empty result: stamping over its window
  # would drop whatever was identified during it.
  def test_a_failed_poll_leaves_the_watermark_where_it_was
    alerting_row
    stub_request(:get, inat_api_matcher("observations")).
      to_return(status: 500)
    before = @site.last_alert_poll_at
    scanner = Inat::AlertScanner.new(site: @site)

    assert_empty(scanner.scan)
    assert_equal(before.to_i, @site.reload.last_alert_poll_at.to_i)
    assert_match(/stays open/, scanner.warnings.first)
  end

  # The pages that did arrive are still matched; the window reopening
  # only means those observations are read again next cycle.
  def test_a_poll_that_fails_partway_keeps_what_it_read
    alerting_row
    responses = [{ status: 200,
                   body: { results: [observation,
                                     observation("id" => 12_346)] }.to_json },
                 { status: 500 }]
    stub_request(:get, inat_api_matcher("observations")).
      to_return(responses)
    before = @site.last_alert_poll_at
    scanner = Inat::AlertScanner.new(site: @site, page_size: 2, max_pages: 2)

    digests = scanner.scan

    assert_equal(1, scanner.alerts_sent)
    assert_not_empty(digests)
    assert_equal(before.to_i, @site.reload.last_alert_poll_at.to_i)
  end

  # The site carries fields this cycle has no opinion about; stamping
  # the watermark shouldn't be blocked by one of them being invalid.
  def test_the_watermark_is_stamped_on_a_site_failing_validation
    alerting_row
    stub_observations([])
    @site.update_column(:base_url, "")
    before = @site.last_alert_poll_at

    scan

    assert_not_predicate(@site.reload, :valid?)
    assert_operator(@site.last_alert_poll_at, :>, before)
  end
end
