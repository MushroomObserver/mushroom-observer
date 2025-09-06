# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Observation search
# ------------------------------------------------------------
module Observations
  class SearchControllerTest < FunctionalTestCase
    def test_show
      login
      get(:show)
      assert_template("observations/search/_help")
    end

    def test_new_observations_search
      login("rolf")
      get(:new)
    end

    def test_new_observations_search_from_existing_query
      proj1 = projects(:bolete_project)
      proj2 = projects(:two_list_project)

      login
      query = @controller.find_or_create_query(
        :Observation,
        names: { lookup: "petigera", include_synonyms: true },
        region: "Massachusetts, USA",
        has_specimen: true,
        notes_has: "Symbiota",
        projects: [proj1.id, proj2.id],
        confidence: %w[1 2]
      )
      assert(query.id)
      assert_equal(query.id, session[:query_record])
      get(:new)
      assert_select("textarea#query_observations_names_lookup",
                    text: "petigera")
      assert_select("select#query_observations_names_include_synonyms",
                    selected: "yes")
      # assert_select("input#query_observations_region",
      #               text: "Massachusetts, USA")
      assert_select("select#query_observations_has_specimen",
                    selected: "yes")
      assert_select("input#query_observations_notes_has", value: "Symbiota")
      # assert_select("textarea#query_observations_projects",
      #               text: proj1.title)
      assert_select("select#query_observations_confidence",
                    selected: "Species")
      assert_select("select#query_observations_confidence_range",
                    selected: "Form")
    end

    def test_create_observations_search
      login
      params = {
        pattern: "Agaricus campestris",
        has_notes: true
      }
      post(:create, params:)
    end

    def test_create_observations_search_nested
      login
      params = {
        names: {
          lookup: "Agaricus campestris",
          include_synonyms: true
        },
        has_notes: true
      }
      post(:create, params:)
    end
  end
end
