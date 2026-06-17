# frozen_string_literal: true

require("test_helper")

module Locations
  class MapsControllerTest < FunctionalTestCase

    def test_map_locations_all
      login
      get(:show)
      assert_select("body.maps__show")
    end

    def test_map_locations_empty
      login
      get(:show, params: { pattern: "Never Never Land" })
      assert_select("body.maps__show")
    end

    def test_map_locations_some
      login
      get(:show, params: { pattern: "California" })
      assert_select("body.maps__show")
    end
  end
end
