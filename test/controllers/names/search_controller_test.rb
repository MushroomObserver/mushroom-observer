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

    def test_new_names_search
      login
      get(:new)
    end

    def test_create_names_search
      login
      params = {
        pattern: "Agaricus campestris",
        misspellings: :either
      }
      post(:create, params:)
    end

    def test_create_names_search_nested
      login
      params = {
        names: {
          lookup: "Agaricus campestris",
          include_synonyms: true
        },
        misspellings: :either
      }
      post(:create, params:)
    end
  end
end
