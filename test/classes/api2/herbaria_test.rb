# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::HerbariaTest < UnitTestCase
  include API2Extensions

  def test_basic_herbarium_get
    do_basic_get_test(Herbarium)
  end

  # -------------------------------
  #  :section: Herbarium Requests
  # -------------------------------

  def test_getting_herbaria
    params = {
      method: :get,
      action: :herbarium
    }

    herbs = Herbarium.created_on("2012-10-21")
    assert_not_empty(herbs)
    assert_api_pass(params.merge(created_at: "2012-10-21"))
    assert_api_results(herbs)

    herbs = [herbaria(:nybg_herbarium)]
    assert_not_empty(herbs)
    assert_api_pass(params.merge(updated_at: "2012-10-21 12:14"))
    assert_api_results(herbs)

    herbs = Herbarium.where(code: "NY")
    assert_not_empty(herbs)
    assert_api_pass(params.merge(code: "NY"))
    assert_api_results(herbs)

    herbs = Herbarium.where(Herbarium[:name].matches("%personal%"))
    assert_not_empty(herbs)
    assert_api_pass(params.merge(name: "personal"))
    assert_api_results(herbs)

    herbs = Herbarium.where(Herbarium[:description].matches("%awesome%"))
    assert_not_empty(herbs)
    assert_api_pass(params.merge(description: "awesome"))
    assert_api_results(herbs)

    herbs = Herbarium.where(Herbarium[:mailing_address].matches("%New York%"))
    assert_not_empty(herbs)
    assert_api_pass(params.merge(address: "New York"))
    assert_api_results(herbs)
  end
end
