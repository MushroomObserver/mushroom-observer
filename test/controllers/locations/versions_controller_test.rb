# frozen_string_literal: true

require("test_helper")
require("set")

module Locations
  class VersionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_show_past_location
      location = locations(:albion)
      login
      get(:show,
          params: { id: location.id, version: location.version - 1 })
      assert_template("locations/versions/show")
      assert_template("locations/show/_location")
    end

    def test_show_past_location_no_version
      location = locations(:albion)
      get(:show, params: { id: location.id })
      assert_response(:redirect)
    end
  end
end
