# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Observation search
# ------------------------------------------------------------
module Observations
  class SearchControllerTest < FunctionalTestCase
    def test_show_help
      login
      get(:show)
      assert_template("observations/search/_help")
    end

    def test_show_help_turbo
      login
      get(:show, format: :turbo_stream)
      assert_template("observations/search/_help")
    end

    def test_new_observations_search
      login("rolf")
      get(:new)
      assert_template("observations/search/new")
      assert_template("shared/_search_form")
    end

    def test_new_observations_search_turbo
      login("rolf")
      get(:new, format: :turbo_stream)
      assert_template("shared/_search_form")
    end

    def test_new_observations_search_form_prefilled_from_existing_query
      proj1 = projects(:bolete_project)
      proj2 = projects(:two_list_project)

      login
      query = @controller.find_or_create_query(
        :Observation,
        names: { lookup: "peltigera", include_synonyms: true },
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
                    text: "peltigera")
      assert_select("select#query_observations_names_include_synonyms",
                    selected: "yes")
      assert_select("input#query_observations_region",
                    value: "Massachusetts, USA")
      assert_select("select#query_observations_has_specimen",
                    selected: "yes")
      assert_select("input#query_observations_notes_has", value: "Symbiota")
      assert_select("input#query_observations_projects_id",
                    value: "#{proj1.id} #{proj2.id}") # hidden ids field
      assert_select("textarea#query_observations_projects",
                    text: "#{proj1.title}\n#{proj2.title}")
      assert_select("select#query_observations_confidence",
                    selected: "Species")
      assert_select("select#query_observations_confidence_range",
                    selected: "Form")
      assert_equal(session[:search_type], :observations)
    end

    # query_observations is the form object.
    def test_create_observations_search
      login
      params = {
        by_users: rolf.unique_text_name,
        by_users_id: rolf.id, # autocompleter should supply
        has_notes: true,
        lichen: false
      }
      post(:create, params: { query_observations: params })

      validated_params = {
        by_users: [rolf.id],
        has_notes: true,
        lichen: false # this should be preserved, not "compacted" out.
      }
      assert_redirected_to(controller: "/observations", action: :index,
                           params: {
                             q: { model: :Observation, **validated_params }
                           })
    end

    def test_create_observations_search_nested
      login
      projects = [projects(:bolete_project), projects(:eol_project)]
      location = locations(:burbank)
      today = Time.zone.today
      todate = format("%04d-%02d-%02d", today.year, today.mon, today.day)
      params = {
        names: {
          lookup: "Agaricus campestris",
          include_synonyms: true
        },
        in_box: location.bounding_box,
        confidence: 33,
        confidence_range: 66,
        has_notes: true,
        projects_id: projects.pluck(:id).join(","),
        date: "2021-01-06-today"
      }
      post(:create, params: { query_observations: params })

      # The controller joins :confidence and :confidence_range into an array.
      # Query validation turns :projects and :lookup into arrays.
      validated_params = {
        names: {
          lookup: ["Agaricus campestris"],
          include_synonyms: true
        },
        in_box: location.bounding_box,
        confidence: [33.0, 66.0],
        has_notes: true,
        projects: projects.pluck(:id),
        date: ["2021-01-06", todate]
      }
      assert_redirected_to(
        controller: "/observations", action: :index,
        params: { q: { model: :Observation, **validated_params } }
      )
    end

    # Check that empty nested-names-params do not interfere with the query.
    def test_create_observations_search_in_box
      login
      location = locations(:burbank)
      params = {
        names: {
          lookup: "",
          include_synonyms: ""
        },
        in_box: location.bounding_box
      }
      post(:create, params: { query_observations: params })
      assert_redirected_to(
        controller: "/observations", action: :index,
        params: { q: { model: :Observation, **params.except(:names) } }
      )
    end
  end
end
