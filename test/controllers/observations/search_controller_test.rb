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
      assert_select("#observations_search_form")
    end

    def test_new_observations_search_turbo
      login("rolf")
      get(:new, format: :turbo_stream)
      assert_select("#observations_search_form")
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
                    value: "#{proj1.id},#{proj2.id}") # hidden ids field
      assert_select("textarea#query_observations_projects",
                    text: "#{proj1.title}\n#{proj2.title}")
      assert_select("select#query_observations_confidence",
                    selected: "Species")
      assert_select("select#query_observations_confidence_range",
                    selected: "Form")
      assert_equal(session[:search_type], :observations)
    end

    def test_new_observations_search_form_prefilled_by_users
      user1 = users(:rolf)
      user2 = users(:mary)

      login
      query = @controller.find_or_create_query(
        :Observation,
        by_users: [user1.id, user2.id]
      )
      assert(query.id)
      get(:new)
      # Check both textarea and hidden ID field are prefilled
      expected_text = "#{user1.unique_text_name}\n#{user2.unique_text_name}"
      assert_select("textarea#query_observations_by_users", text: expected_text)
      assert_select("input#query_observations_by_users_id",
                    value: "#{user1.id},#{user2.id}")
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

    # ---------------------------------------------------------------
    #  Multi-value autocompleter tests (newline-separated values)
    #  Test each autocompleter type once to verify multi-value handling
    # ---------------------------------------------------------------

    def test_create_with_multiple_users
      login
      user1 = users(:rolf)
      user2 = users(:mary)
      params = {
        by_users: "#{user1.unique_text_name}\n#{user2.unique_text_name}",
        by_users_id: "#{user1.id},#{user2.id}"
      }
      post(:create, params: { query_observations: params })

      assert_redirected_to(
        controller: "/observations", action: :index,
        params: { q: { model: :Observation, by_users: [user1.id, user2.id] } }
      )
    end

    def test_create_with_multiple_projects
      login
      proj1 = projects(:bolete_project)
      proj2 = projects(:eol_project)
      params = {
        projects: "#{proj1.title}\n#{proj2.title}",
        projects_id: "#{proj1.id},#{proj2.id}"
      }
      post(:create, params: { query_observations: params })

      assert_redirected_to(
        controller: "/observations", action: :index,
        params: { q: { model: :Observation, projects: [proj1.id, proj2.id] } }
      )
    end

    def test_create_with_multiple_herbaria
      login
      herb1 = herbaria(:nybg_herbarium)
      herb2 = herbaria(:fundis_herbarium)
      params = {
        herbaria: "#{herb1.name}\n#{herb2.name}",
        herbaria_id: "#{herb1.id},#{herb2.id}"
      }
      post(:create, params: { query_observations: params })

      assert_redirected_to(
        controller: "/observations", action: :index,
        params: { q: { model: :Observation, herbaria: [herb1.id, herb2.id] } }
      )
    end

    def test_create_with_multiple_locations
      login
      loc1 = locations(:burbank)
      loc2 = locations(:albion)
      # NOTE: within_locations uses location names, not IDs
      params = {
        within_locations: "#{loc1.name}\n#{loc2.name}"
      }
      post(:create, params: { query_observations: params })

      # Location names are passed as-is (not converted to IDs)
      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: {
            model: :Observation,
            within_locations: ["#{loc1.name}\n#{loc2.name}"]
          }
        }
      )
    end

    def test_create_with_multiple_species_lists
      login
      list1 = species_lists(:first_species_list)
      list2 = species_lists(:another_species_list)
      params = {
        species_lists: "#{list1.title}\n#{list2.title}",
        species_lists_id: "#{list1.id},#{list2.id}"
      }
      post(:create, params: { query_observations: params })

      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: { model: :Observation, species_lists: [list1.id, list2.id] }
        }
      )
    end

    def test_create_with_multiple_names_lookup
      login
      params = {
        names: {
          lookup: "Agaricus campestris\nCoprinus comatus"
        }
      }
      post(:create, params: { query_observations: params })

      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: {
            model: :Observation,
            names: { lookup: ["Agaricus campestris", "Coprinus comatus"] }
          }
        }
      )
    end

    # ---------------------------------------------------------------
    #  Range value ordering tests
    #  Ensure that range values are sorted correctly regardless of input order
    # ---------------------------------------------------------------

    def test_create_with_confidence_range_reversed
      # Submit with high value first, low value second - should be sorted
      login
      params = {
        confidence: 2.0,       # high value
        confidence_range: -1.0 # low value
      }
      post(:create, params: { query_observations: params })

      # Should be sorted as [low, high] = [-1.0, 2.0]
      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: { model: :Observation, confidence: [-1.0, 2.0] }
        }
      )
    end

    def test_create_with_confidence_range_correct_order
      # Submit with low value first, high value second - should stay same
      login
      params = {
        confidence: -1.0,     # low value
        confidence_range: 2.0 # high value
      }
      post(:create, params: { query_observations: params })

      # Should remain as [-1.0, 2.0]
      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: { model: :Observation, confidence: [-1.0, 2.0] }
        }
      )
    end

    # ---------------------------------------------------------------
    #  Confidence range prefill tests
    # ---------------------------------------------------------------

    def test_prefill_confidence_range_both_negative
      # Bug: "As If!" (-3.0) to "Doubtful" (-1.0) - first select was blank
      login
      query = @controller.find_or_create_query(
        :Observation,
        confidence: [-3.0, -1.0]
      )
      assert(query.id)
      get(:new)

      # Both selects should be prefilled
      assert_select("select#query_observations_confidence", selected: "As If!")
      assert_select("select#query_observations_confidence_range",
                    selected: "Doubtful")
    end

    def test_prefill_confidence_range_from_url_params
      # Bug: Loading search/new with q params didn't prefill first confidence
      # URL: /observations/search/new?q[confidence][]=-3.0&q[confidence][]=-1.0
      login

      q_params = { q: { model: "Observation", confidence: [-3.0, -1.0] } }
      get(:new, params: q_params)

      # Both selects should be prefilled
      assert_select("select#query_observations_confidence", selected: "As If!")
      assert_select("select#query_observations_confidence_range",
                    selected: "Doubtful")
    end
  end
end
