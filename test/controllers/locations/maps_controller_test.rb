# frozen_string_literal: true

require "test_helper"

module Locations
  class MapsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_map_locations_all
      login
      get(:show)
      assert_template("locations/maps/show")
    end

    def test_map_locations_empty
      login
      get(:show, params: { pattern: "Never Never Land" })
      assert_template("locations/maps/show")
    end

    def test_map_locations_some
      login
      get(:show, params: { pattern: "California" })
      assert_template("locations/maps/show")
    end
  end
end
