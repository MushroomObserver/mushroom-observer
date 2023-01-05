# frozen_string_literal: true

require("test_helper")
require("set")

module Locations
  class CountriesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_list_countries
      login
      get(:index)
      assert_template("index")
    end
  end
end
