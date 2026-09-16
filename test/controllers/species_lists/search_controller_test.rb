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
      assert_select("#species_lists_search_form")
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
                    text: "Mary Newbie (mary)\nKatrina (katrina)")
      assert_select("input#query_species_lists_title_has", value: "Symbiota")
      assert_select("select#query_species_lists_has_notes", selected: "yes")
      assert_select("textarea#query_species_lists_names_lookup",
                    text: "Boletus edulis")
      assert_equal(:species_lists, session[:search_type])
    end

    def test_create_species_lists_search
      login
      params = {
        title_has: "No",
        has_comments: false, # scope ignores false values
        region: "Oregon, USA"
      }
      post(:create, params: { query_species_lists: params })

      validated_params = params.except(:has_comments)
      assert_search_redirected_to(
        controller: "/species_lists",
        params: validated_params
      )
    end

    def test_create_species_lists_search_invalid_params
      login
      fake_query = FakeInvalidQuery.new(["Something went wrong."])

      Query.stub(:create_query, fake_query) do
        post(:create, params: { query_species_lists: { title_has: "x" } })
      end

      assert_redirected_to(action: :new)
      assert_flash_error
    end

    # Stands in for a Query whose validation failed -- easier and more
    # reliable than constructing real search params that survive
    # Query's own param-cleaning to reach #invalid? as false.
    class FakeInvalidQuery
      def initialize(messages)
        @messages = messages
      end

      def invalid?
        true
      end

      def validation_error_messages
        @messages
      end
    end
  end
end
