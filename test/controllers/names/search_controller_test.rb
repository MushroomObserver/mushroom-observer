# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Names search - test pattern search
# ------------------------------------------------------------
module Names
  class SearchControllerTest < FunctionalTestCase
    def test_get_form
      login("rolf")
      get(:new)
    end
  end
end
