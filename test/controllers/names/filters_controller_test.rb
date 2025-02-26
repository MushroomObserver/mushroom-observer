# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Name filters - test pattern search
# ------------------------------------------------------------
module Names
  class FiltersControllerTest < FunctionalTestCase
    def test_existing_name_pattern
      login("rolf")
      # may need to do this in an integration test
      # @request.session["pattern"] = "something"
      # @request.session["search_type"] = "name"
      get(:new)
      # assert_select("input[type=text]#name_filter_pattern",
      #               text: "something", count: 1)
    end
  end
end
