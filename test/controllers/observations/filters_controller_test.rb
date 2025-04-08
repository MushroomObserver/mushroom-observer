# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Observation filters - test pattern search
# ------------------------------------------------------------
module Observations
  class FiltersControllerTest < FunctionalTestCase
    def test_existing_obs_pattern
      login("rolf")
      # may need to do this in an integration test
      # @request.session["pattern"] = "something"
      # @request.session["search_type"] = "observation"
      get(:new)
    end
  end
end
