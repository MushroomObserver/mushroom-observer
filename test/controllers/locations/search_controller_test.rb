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
      location = locations(:burbank)
      box = location.bounding_box
      query = @controller.find_or_create_query(
        :Location,
        in_box: box,
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
      assert_select("input#query_locations_in_box_south", value: box[:south])
      assert_select("select#query_locations_has_notes", selected: "yes")
      assert_select("input#query_locations_notes_has", value: "Symbiota")
      assert_select("input#query_locations_pattern", value: "anything")
      assert_select("input#query_locations_regexp", value: "Target")
      assert_select("input#query_locations_by_editor", value: "Rolf Singer")
      assert_select("select#query_locations_has_observations",
                    selected: "yes")
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
