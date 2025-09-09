# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Locations search
# ------------------------------------------------------------
module Locations
  class SearchControllerTest < FunctionalTestCase
    def test_new_locations_search
      login
      get(:new)
    end

    def test_new_locations_search_form_prefilled_from_existing_query
      login
      query = @controller.find_or_create_query(
        :Location,
        in_box: locations(:burbank).bounding_box,
        has_notes: true,
        notes_has: "Symbiota",
        pattern: "anything",
        regexp: "Target",
        by_editor: users(:rolf).id,
        has_observations: true
      )
      assert(query.id)
      assert_equal(query.id, session[:query_record])
      get(:new)
      assert_select("textarea#query_locations_names_lookup", text: "petigera")
      assert_select("select#query_locations_names_include_synonyms",
                    selected: "yes")
      assert_select("select#query_locations_misspellings", selected: "either")
      assert_select("select#query_locations_has_classification",
                    selected: "yes")
      assert_select("input#query_locations_author_has", value: "Pers.")
      assert_select("select#query_locations_rank", selected: "Species")
      assert_select("select#query_locations_rank_range", selected: "Form")
    end

    def test_create_locations_search
      login
      params = {
        pattern: "Agaricus campestris",
        misspellings: :either
      }
      post(:create, params: { query_locations: params })

      assert_redirected_to(controller: "/locations", action: :index,
                           params: { q: { model: :Location, **params } })
    end

    def test_create_locations_search_nested
      login
      params = {
        locations: {
          lookup: "Agaricus campestris",
          include_synonyms: true
        },
        rank: :Species,
        rank_range: :Genus,
        misspellings: :either
      }
      post(:create, params: { query_locations: params })

      # The controller joins :rank and :rank_range into an array.
      # Query validation turns :lookup into an array.
      validated_params = {
        locations: {
          lookup: ["Agaricus campestris"],
          include_synonyms: true
        },
        rank: [:Species, :Genus],
        misspellings: :either
      }
      assert_redirected_to(controller: "/locations", action: :index,
                           params: { q: { model: :Location, **validated_params } })
    end
  end
end
