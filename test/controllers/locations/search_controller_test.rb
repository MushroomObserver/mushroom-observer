# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Locations search
# ------------------------------------------------------------
module Locations
  class SearchControllerTest < FunctionalTestCase
    def test_show_help
      login
      get(:show)
      assert_template("locations/search/_help")
    end

    def test_show_help_turbo
      login
      get(:show, format: :turbo_stream)
      assert_template("locations/search/_help")
    end

    def test_new_locations_search
      login
      get(:new)
    end

    def test_new_locations_search_turbo
      login
      get(:new, format: :turbo_stream)
      assert_select("#locations_search_form")
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
        regexp: "Target",
        by_editor: [users(:rolf).id],
        has_observations: true
      )
      assert(query.id)
      assert_equal(query.id, session[:query_record])
      get(:new)
      assert_select("input#query_locations_in_box_south", value: box[:south])
      assert_select("select#query_locations_has_notes", selected: "yes")
      assert_select("input#query_locations_notes_has", value: "Symbiota")
      assert_select("input#query_locations_regexp", value: "Target")
      assert_select("textarea#query_locations_by_editor",
                    text: "Rolf Singer (rolf)")
      assert_select("select#query_locations_has_observations",
                    selected: "yes")
      assert_equal(session[:search_type], :locations)
    end

    def test_create_locations_search
      login
      params = {
        regexp: "urbank",
        has_observations: true
      }
      post(:create, params: { query_locations: params })

      assert_redirected_to(controller: "/locations", action: :index,
                           params: { q: { model: :Location, **params } })
    end

    def test_create_locations_search_nested
      login
      location = locations(:california)
      box = location.bounding_box
      params = {
        in_box: box,
        region: "California, USA",
        by_users: "mary"
      }
      post(:create, params: { query_locations: params })

      # Query validation parses region as an array of region strings.
      validated_params = {
        in_box: box,
        region: ["California, USA"],
        by_users: %w[mary]
      }
      assert_redirected_to(
        controller: "/locations", action: :index,
        params: { q: { model: :Location, **validated_params } }
      )
    end
  end
end
