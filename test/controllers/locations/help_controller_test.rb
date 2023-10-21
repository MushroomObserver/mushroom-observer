# frozen_string_literal: true

require("test_helper")
require("set")

module Locations
  class HelpControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_location_help
      get(:show)
    end
  end
end
