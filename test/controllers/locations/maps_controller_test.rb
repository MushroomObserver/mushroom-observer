# frozen_string_literal: true

require("test_helper")
require("set")

module Locations
  class MapsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_map_locations
      login
      # test_map_locations - map everything
      get(:map_locations)
      assert_template("map_locations")

      # test_map_locations_empty - map nothing
      get(:map_locations, params: { pattern: "Never Never Land" })
      assert_template("map_locations")

      # test_map_locations_some - map something
      get(:map_locations, params: { pattern: "California" })
      assert_template("map_locations")
    end
  end
end
