# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::ExternalSitesTest < UnitTestCase
  include API2Extensions

  def test_basic_external_site_get
    do_basic_get_test(ExternalSite)
  end

  # ----------------------------------
  #  :section: ExternalSite Requests
  # ----------------------------------

  def api2_model = ExternalSite

  def test_getting_external_sites
    sites = ExternalSite.where(ExternalSite[:name].matches("%inat%"))
    assert_not_empty(sites)
    assert_api_pass(params_get(name: "inat"))
    assert_api_results(sites)
  end
end
