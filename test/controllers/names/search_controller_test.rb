# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Names search
# ------------------------------------------------------------
module Names
  class SearchControllerTest < FunctionalTestCase
    def test_show
      login
      get(:show)
    end
  end
end
