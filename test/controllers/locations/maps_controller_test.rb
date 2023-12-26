# frozen_string_literal: true

require("test_helper")

module Locations
  class MapsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_map_locations
      login
      # test_map_locations - map everything
      get(:show)
      assert_template("locations/maps/show")

      # test_map_locations_empty - map nothing
      get(:show, params: { pattern: "Never Never Land" })
      assert_template("locations/maps/show")

      # test_map_locations_some - map something
      get(:show, params: { pattern: "California" })
      assert_template("locations/maps/show")
    end
  end
end
