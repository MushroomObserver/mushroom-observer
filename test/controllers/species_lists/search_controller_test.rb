# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  SpeciesLists search
# ------------------------------------------------------------
module SpeciesLists
  class SearchControllerTest < FunctionalTestCase
    def test_new_species_lists_search
      login
      get(:new)
    end

    def test_new_species_lists_search_turbo
      login
      get(:new, format: :turbo_stream)
      assert_template("shared/_search_form")
    end

    def test_new_species_lists_search_form_prefilled_from_existing_query
      login
      query = @controller.find_or_create_query(
        :SpeciesList,
        by_users: [users(:mary).id, users(:katrina).id],
        title_has: "Symbiota",
        has_notes: true,
        names: { lookup: "Boletus edulis" }
      )
      assert(query.id)
      assert_equal(query.id, session[:query_record])
      get(:new)
      assert_select("textarea#query_species_lists_by_users",
                    text: "Mary Newbie\nKatrina")
      assert_select("input#query_species_lists_title_has", value: "Symbiota")
      assert_select("select#query_species_lists_has_notes", selected: "yes")
      assert_select("textarea#query_species_lists_names_lookup",
                    text: "Boletus edulis")
    end

    def test_create_species_lists_search
      login
      params = {
        title_has: "Symbiota",
        has_comments: true
      }
      post(:create, params: { query_species_lists: params })

      assert_redirected_to(controller: "/species_lists", action: :index,
                           params: { q: { model: :SpeciesList, **params } })
    end
  end
end
