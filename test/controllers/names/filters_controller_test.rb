# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Name filters - test pattern search
# ------------------------------------------------------------
module Names
  class FiltersControllerTest < FunctionalTestCase
    def test_existing_pattern
      @request.session["pattern"] = "something"
      @request.session["search_type"] = "name"
      get(:new)
    end
  end
end
