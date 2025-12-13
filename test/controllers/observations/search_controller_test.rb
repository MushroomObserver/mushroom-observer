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

    # Test that multiple users in by_users are properly prefilled
    def test_new_observations_search_form_prefilled_with_multiple_users
      user1 = users(:rolf)
      user2 = users(:mary)
      user3 = users(:dick)

      login
      query = @controller.find_or_create_query(
        :Observation,
        by_users: [user1.id, user2.id, user3.id]
      )
      assert(query.id)
      get(:new)
      # Textarea should show newline-separated user names
      assert_select(
        "textarea#query_observations_by_users",
        text: "#{user1.unique_text_name}\n#{user2.unique_text_name}\n" \
              "#{user3.unique_text_name}"
      )
      # Hidden field should have space-separated ids
      assert_select(
        "input#query_observations_by_users_id",
        value: "#{user1.id} #{user2.id} #{user3.id}"
      )
    end

    def test_new_observations_search_form_prefilled_with_has_field_slips
      login
      query = @controller.find_or_create_query(
        :Observation,
        has_field_slips: true,
        has_images: false
      )
      assert(query.id)
      get(:new)
      assert_select("select#query_observations_has_field_slips",
                    selected: "yes")
      assert_select("select#query_observations_has_images",
                    selected: "no")
    end

    def test_new_observations_search_form_prefilled_with_has_collection_numbers
      login
      query = @controller.find_or_create_query(
        :Observation,
        has_collection_numbers: true,
        has_notes: false
      )
      assert(query.id)
      get(:new)
      assert_select("select#query_observations_has_collection_numbers",
                    selected: "yes")
      assert_select("select#query_observations_has_notes",
                    selected: "no")
    end

    def test_new_observations_search_form_retains_include_subtaxa_false
      login
      # Create a query with a name lookup and include_subtaxa explicitly false
      query = @controller.find_or_create_query(
        :Observation,
        names: { lookup: "Agaricus", include_subtaxa: false }
      )
      assert(query.id)
      get(:new)
      # Verify that both the lookup and include_subtaxa are retained
      assert_select("textarea#query_observations_names_lookup",
                    text: "Agaricus")
      assert_select("select#query_observations_names_include_subtaxa",
                    selected: "no")
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

    def test_create_observations_search_with_blank_name_and_include_subtaxa
      login
      # Simulate form submission with no name but include_subtaxa
      # defaulted to true
      params = {
        names: {
          lookup: "",
          include_subtaxa: "true"
        }
      }
      post(:create, params: { query_observations: params })
      # Should redirect to observations index with no names param
      assert_redirected_to(controller: "/observations", action: :index,
                           params: { q: { model: :Observation } })
    end

    # Test reset_search_query creates a new blank query
    def test_reset_search_query_creates_blank_query
      login

      # First, create a query with parameters
      query = @controller.find_or_create_query(
        :Observation,
        names: { lookup: "Agaricus" },
        has_specimen: true
      )
      original_query_id = query.id
      assert(query.params.present?, "Original query should have params")

      # Now load the form with clear=1, which triggers reset_search_query
      get(:new, params: { clear: "1" })

      # Verify a NEW query was created (different ID)
      new_query = @controller.instance_variable_get(:@search)
      assert_not_equal(original_query_id, new_query.id,
                       "reset_search_query should create a NEW query")

      # Verify the new query is blank (no params)
      assert(new_query.params.blank? || new_query.params == {},
             "reset_search_query should create a BLANK query with no params")

      # Verify session[:names_preferences] was deleted
      assert_nil(session[:names_preferences],
                 "reset_search_query should delete names_preferences")
    end

    # Test clear_form? when commit button is "Clear"
    def test_clear_form_with_clear_button
      login

      # First, create a query with parameters
      query = @controller.find_or_create_query(
        :Observation,
        names: { lookup: "Coprinus comatus" },
        has_specimen: true
      )
      query.id
      assert(query.params.present?, "Original query should have params")

      # Post to create with commit="Clear" (the localized CLEAR button value)
      # This triggers clear_form? which calls clear_relevant_query and redirects
      post(:create, params: {
             query_observations: {
               names: { lookup: "Agaricus" }
             },
             commit: :CLEAR.l # This is "Clear" in English
           })

      # Verify it redirected to :new (not to index with search results)
      # This proves clear_form? returned true and the early return was triggered
      assert_redirected_to(action: :new)

      # Now load the form to verify the query was cleared
      get(:new)
      cleared_query = @controller.instance_variable_get(:@search)

      # The query should have blank params after being cleared
      assert(cleared_query.params.blank? || cleared_query.params == {},
             "clear_form? should result in a blank query")
    end

    def test_create_observations_search_with_has_field_slips
      login
      params = {
        has_field_slips: true,
        has_images: false
      }
      post(:create, params: { query_observations: params })

      validated_params = {
        has_field_slips: true,
        has_images: false
      }
      assert_redirected_to(controller: "/observations", action: :index,
                           params: {
                             q: { model: :Observation, **validated_params }
                           })
    end

    def test_create_observations_search_with_has_collection_numbers
      login
      params = {
        has_collection_numbers: true,
        has_notes: false
      }
      post(:create, params: { query_observations: params })

      validated_params = {
        has_collection_numbers: true,
        has_notes: false
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

    # ---------------------------------------------------------------
    #  Single value confidence tests (blank + value scenarios)
    #  Regression test for bug where selecting only the second dropdown
    #  caused validation errors due to nil values
    # ---------------------------------------------------------------

    def test_create_with_only_confidence_range_value
      # Submit with first dropdown blank, only second dropdown selected
      # This previously caused validation errors with [nil, 2.0]
      login
      params = {
        confidence: "", # blank/empty
        confidence_range: 2.0 # only this one selected
      }
      post(:create, params: { query_observations: params })

      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: { model: :Observation, confidence: [2.0] }
        }
      )
    end

    def test_create_with_only_first_confidence_value
      # Submit with only first dropdown selected, second blank
      login
      params = {
        confidence: 1.0,
        confidence_range: "" # blank/empty
      }
      post(:create, params: { query_observations: params })

      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: { model: :Observation, confidence: [1.0] }
        }
      )
    end

    def test_create_with_both_confidence_values_blank
      # Submit with both dropdowns blank (no confidence filter)
      login
      params = {
        confidence: "",
        confidence_range: "",
        has_images: true # add another param so query isn't completely empty
      }
      post(:create, params: { query_observations: params })

      # Should create query without confidence parameter
      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: { model: :Observation, has_images: true }
        }
      )
    end

    # ---------------------------------------------------------------
    #  "No Opinion" (0) special case tests
    # ---------------------------------------------------------------

    def test_create_with_no_opinion_searches_for_exact_zero
      # User selects "No Opinion" (0) in first dropdown, second blank
      # Should search for exactly vote_cache = 0, not >= 0
      login
      params = {
        confidence: 0,
        confidence_range: ""
      }
      post(:create, params: { query_observations: params })

      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: { model: :Observation, confidence: [0.0] }
        }
      )
    end

    def test_prefill_no_opinion_confidence
      # Bug: "No Opinion" (0) should display correctly, not be filled with max
      login
      query = @controller.find_or_create_query(
        :Observation,
        confidence: [0]
      )
      assert(query.id)
      get(:new)

      # First select should have "No Opinion" (0) selected
      assert_select("select#query_observations_confidence") do
        assert_select("option[selected][value='0']")
      end
      # Second select should have blank option selected (exact match,
      # not a range)
      assert_select("select#query_observations_confidence_range") do
        assert_select("option[selected]") do |options|
          assert_equal(1, options.length)
          # The blank option has an empty or nil value attribute
          assert(
            options.first["value"].blank?,
            "Second confidence dropdown should have blank value for No Opinion"
          )
        end
      end
    end

    # ---------------------------------------------------------------
    #  Notes fields normalization tests
    # ---------------------------------------------------------------

    def test_create_with_has_notes_fields_converts_spaces
      login
      # User types friendly field name with spaces
      params = { has_notes_fields: "INat notes field" }
      post(:create, params: { query_observations: params })

      # Spaces should be converted to underscores, case preserved
      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: { model: :Observation, has_notes_fields: ["INat_notes_field"] }
        }
      )
    end

    def test_create_with_multiple_notes_fields_newline_separated
      login
      # User types multiple fields separated by newlines (textarea input)
      params = { has_notes_fields: "Substrate\nCap Color\nOther Field" }
      post(:create, params: { query_observations: params })

      # Should be split on newline, spaces converted to underscores
      assert_redirected_to(
        controller: "/observations", action: :index,
        params: {
          q: {
            model: :Observation,
            has_notes_fields: %w[Substrate Cap_Color Other_Field]
          }
        }
      )
    end

    # ------- Server Handling of Long Inputs (POST method) -------
    # These tests prove that when long inputs reach the server (if JS fails),
    # the server can handle them without crashing since POST puts data in body

    def test_server_handles_very_long_input_without_error
      login
      # Create input that would exceed URL limits but is fine in POST body
      long_text = "x" * 15_000 # Well over 9500 limit
      params = {
        notes_has: long_text,
        has_specimen: true
      }

      # Should not raise an error, even though JS validation would prevent this
      assert_nothing_raised do
        post(:create, params: { query_observations: params })
      end

      # Should successfully create search and redirect
      assert_response(:redirect)
      assert_match(/observations/, response.redirect_url)
    end

    def test_server_handles_multiple_long_fields
      login
      # Multiple long fields that collectively would be problematic in URL
      long_text1 = "a" * 8000
      long_text2 = "b" * 8000
      params = {
        notes_has: long_text1,
        comments_has: long_text2
      }

      assert_nothing_raised do
        post(:create, params: { query_observations: params })
      end

      assert_response(:redirect)
    end

    def test_server_handles_long_nested_params
      login
      # Test with long names lookup
      long_names = (1..1000).map { |i| "Species#{i}" }.join("\n")
      params = {
        names: {
          lookup: long_names,
          include_synonyms: true
        }
      }

      assert_nothing_raised do
        post(:create, params: { query_observations: params })
      end

      assert_response(:redirect)
    end
  end
end
