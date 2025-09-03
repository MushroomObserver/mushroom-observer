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

    def test_new_names_search
      login
      get(:new)
    end

    def test_new_names_search_from_existing_query
      login
      query = @controller.find_or_create_query(
        :Name, pattern: "petigera", misspellings: :either,
               has_classification: true, author_has: "Pers."
      )
      assert(query.id)
      assert_equal(query.id, session[:query_record])
      get(:new)
      assert_select("input#pattern", text: "petigera")
      assert_select("select#misspellings", text: "either")
      assert_select("select#has_classification option[selected]", text: "yes")
      assert_select("input#author_has", text: "Pers.")
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
