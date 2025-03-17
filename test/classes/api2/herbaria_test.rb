# frozen_string_literal: true

require "test_helper"
require "api2_extensions"

class API2::HerbariaTest < UnitTestCase
  include API2Extensions

  def test_basic_herbarium_get
    do_basic_get_test(Herbarium)
  end

  # -------------------------------
  #  :section: Herbarium Requests
  # -------------------------------

  def params_get(**)
    { method: :get, action: :herbarium }.merge(**)
  end

  def test_getting_herbaria_created_at
    herbs = Herbarium.created_on("2012-10-21")
    assert_not_empty(herbs)
    assert_api_pass(params_get(created_at: "2012-10-21"))
    assert_api_results(herbs)
  end

  def test_getting_herbaria_updated_at
    herbs = [herbaria(:nybg_herbarium)]
    assert_not_empty(herbs)
    assert_api_pass(params_get(updated_at: "2012-10-21 12:14"))
    assert_api_results(herbs)
  end

  def test_getting_herbaria_code
    herbs = Herbarium.where(code: "NY")
    assert_not_empty(herbs)
    assert_api_pass(params_get(code: "NY"))
    assert_api_results(herbs)
  end

  def test_getting_herbaria_name
    herbs = Herbarium.where(Herbarium[:name].matches("%personal%"))
    assert_not_empty(herbs)
    assert_api_pass(params_get(name: "personal"))
    assert_api_results(herbs)
  end

  def test_getting_herbaria_description
    herbs = Herbarium.where(Herbarium[:description].matches("%awesome%"))
    assert_not_empty(herbs)
    assert_api_pass(params_get(description: "awesome"))
    assert_api_results(herbs)
  end

  def test_getting_herbaria_address
    herbs = Herbarium.where(Herbarium[:mailing_address].matches("%New York%"))
    assert_not_empty(herbs)
    assert_api_pass(params_get(address: "New York"))
    assert_api_results(herbs)
  end
end
