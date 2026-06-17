# frozen_string_literal: true

require("test_helper")

module Locations
  class HelpControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_location_help
      login
      get(:show)
      assert_response(:success)
      assert_select("body.help__show")
      assert_select("h2", text: :location_help_example_title.l)
    end
  end
end
