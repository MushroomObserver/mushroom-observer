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
      assert_template("observations/search/_help")
    end
  end
end
