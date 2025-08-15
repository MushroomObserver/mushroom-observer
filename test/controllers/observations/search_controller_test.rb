# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Observation search
# ------------------------------------------------------------
module Observations
  class SearchControllerTest < FunctionalTestCase
    def test_show
      login
      get(:show)
    end
  end
end
