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
      assert_template("names/search/_help")
    end
  end
end
