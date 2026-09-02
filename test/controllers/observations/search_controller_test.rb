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
      assert_select("body.search__show")
      assert_select("p", text: /#{:observations.ti} #{:searches.ti}/)
    end

    def test_show_help_turbo
      login
      get(:show, format: :turbo_stream)
      assert_select("turbo-stream[action='update'][target='search_bar_help']")
    end

    def test_new_observations_search
      login("rolf")
      get(:new)
      assert_select("body.search__new")
      assert_select("#observations_search_form")
    end

    def test_new_observations_search_turbo
      login("rolf")
      get(:new, format: :turbo_stream)
      assert_select("#observations_search_form")
    end

    def test_new_observations_search_with_advanced_retired_flag
      login("rolf")
      get(:new, params: { advanced_retired: 1 })
      assert_select("#observations_search_form")
      assert_flash(:search_advanced_retired_notice)
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
      assert_equal(:observations, session[:search_type])
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

    def test_new_observations_search_form_prefilled_with_external_sites
      login
      site = external_sites(:mycoportal)
      query = @controller.find_or_create_query(
        :Observation,
        external_sites: [site.id]
      )
      assert(query.id)
      get(:new)
      assert_select("select#query_observations_external_sites",
                    selected: site.name) do
        assert_select("option[value='#{site.id}']")
      end
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
        by_user: rolf.id,
        has_notes: true,
        lichen: false # this should be preserved, not "compacted" out.
      }
      assert_search_redirected_to(controller: "/observations",
                                  params: validated_params)
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
      assert_search_redirected_to(controller: "/observations",
                                  params: {})
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
             commit: :clear.ti # This is "Clear" in English
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

    # A comma-separated pair of dates is a range; the filter must reach
    # the query (the dash-only parser used to return nil and the search
    # silently ran without the date).
    def test_create_observations_search_with_comma_date_range
      login
      params = {
        region: "Colorado, USA",
        date: "2026-08-12,2026-08-16"
      }
      post(:create, params: { query_observations: params })

      validated_params = {
        region: "Colorado, USA",
        date: %w[2026-08-12 2026-08-16]
      }
      assert_search_redirected_to(controller: "/observations",
                                  params: validated_params)
    end

    # A date the parser can't read must fail the search with an error,
    # never run it with the filter quietly gone.
    def test_create_observations_search_with_unparseable_date
      login
      params = {
        region: "Colorado, USA",
        date: "next Tuesday"
      }
      post(:create, params: { query_observations: params })

      assert_flash_error
      assert_redirected_to(action: :new)
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
      assert_search_redirected_to(controller: "/observations",
                                  params: validated_params)
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
      assert_search_redirected_to(controller: "/observations",
                                  params: validated_params)
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
      assert_search_redirected_to(
        controller: "/observations",
        params: validated_params
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
      assert_search_redirected_to(
        controller: "/observations",
        params: params.except(:names)
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

      assert_search_redirected_to(
        controller: "/observations",
        params: { by_users: [user1.id, user2.id] }
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

      assert_search_redirected_to(
        controller: "/observations",
        params: { projects: [proj1.id, proj2.id] }
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

      assert_search_redirected_to(
        controller: "/observations",
        params: { herbaria: [herb1.id, herb2.id] }
      )
    end

    def test_create_with_external_site
      login
      site = external_sites(:mycoportal)
      params = { external_sites: site.id.to_s }
      post(:create, params: { query_observations: params })

      assert_search_redirected_to(
        controller: "/observations",
        params: { external_site: site.id }
      )
    end

    def test_create_with_multiple_locations
      login
      loc1 = locations(:burbank)
      loc2 = locations(:albion)
      params = {
        within_locations: "#{loc1.name}\n#{loc2.name}"
      }
      post(:create, params: { query_observations: params })

      # Unresolved location names are looked up and redirected as ids.
      assert_search_redirected_to(
        controller: "/observations",
        params: { within_locations: [loc1.id, loc2.id] }
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

      assert_search_redirected_to(
        controller: "/observations",
        params: { species_lists: [list1.id, list2.id] }
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

      assert_search_redirected_to(
        controller: "/observations",
        params: {
          names: { lookup: ["Agaricus campestris", "Coprinus comatus"] }
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
      assert_search_redirected_to(
        controller: "/observations",
        params: { confidence: [-1.0, 2.0] }
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
      assert_search_redirected_to(
        controller: "/observations",
        params: { confidence: [-1.0, 2.0] }
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

      assert_search_redirected_to(
        controller: "/observations",
        params: { confidence: 2.0 }
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

      assert_search_redirected_to(
        controller: "/observations",
        params: { confidence: 1.0 }
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
      assert_search_redirected_to(
        controller: "/observations",
        params: {
          has_images: true
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

      assert_search_redirected_to(
        controller: "/observations",
        params: { confidence: 0.0 }
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
      assert_search_redirected_to(
        controller: "/observations",
        params: { has_notes_fields: "INat_notes_field" }
      )
    end

    def test_create_with_multiple_notes_fields_newline_separated
      login
      # User types multiple fields separated by newlines (textarea input)
      params = { has_notes_fields: "Substrate\nCap Color\nOther Field" }
      post(:create, params: { query_observations: params })

      # Should be split on newline, spaces converted to underscores
      assert_search_redirected_to(
        controller: "/observations",
        params: {
          has_notes_fields: %w[Substrate Cap_Color Other_Field]
        }
      )
    end

    # ------- Server Handling of Long Inputs (POST method) -------
    # These tests prove that when a long input reaches the server (e.g. if
    # client-side JS validation fails or is bypassed), the server rejects
    # it cleanly with a flash error and redirects back to the form --
    # instead of building a redirect URL long enough for a front-end
    # proxy to reject with a hard-to-diagnose error page (issue #5276).

    def test_server_rejects_very_long_single_field
      login
      # A single scalar field (not a multi-value autocompleter, so
      # too_many_multiple_values? doesn't apply) whose serialized
      # redirect URL alone is well over MAX_INDEX_FILTER_URL_LENGTH --
      # proves the aggregate-length guard catches it unassisted.
      long_text = "x" * 15_000
      params = {
        notes_has: long_text,
        has_specimen: true
      }

      assert_nothing_raised do
        post(:create, params: { query_observations: params })
      end

      assert_redirected_to(action: :new)
      assert_flash_error
    end

    def test_server_rejects_multiple_long_fields
      login
      # Two individually plausible scalar fields whose combined
      # redirect URL is still too long.
      long_text1 = "a" * 8000
      long_text2 = "b" * 8000
      params = {
        notes_has: long_text1,
        comments_has: long_text2
      }

      assert_nothing_raised do
        post(:create, params: { query_observations: params })
      end

      assert_redirected_to(action: :new)
      assert_flash_error
    end

    def test_server_rejects_too_many_names
      login
      # Well over MAX_NAME_LOOKUP_VALUES -- rejected outright, without
      # attempting to resolve (resolution only happens between
      # MAX_MULTIPLE_VALUES and MAX_NAME_LOOKUP_VALUES).
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

      assert_redirected_to(action: :new)
      assert_flash_error
    end

    def test_server_rejects_too_many_by_users_values
      login
      too_many = (1..60).map { |i| "user#{i}" }.join("\n")
      params = { by_users: too_many }

      assert_nothing_raised do
        post(:create, params: { query_observations: params })
      end

      assert_redirected_to(action: :new)
      assert_flash_error(
        :runtime_search_too_many_values,
        field: :query_by_users.l.humanize, count: 60,
        max: Searchable::MatchGuards::MAX_MULTIPLE_VALUES
      )
    end

    # too_many_multiple_values? must count the pasted values BEFORE
    # resolve_fields_preferring_ids_to_ids runs -- Herbarium.name_has
    # is a fuzzy match, so if resolution ran first, these 60 identical
    # strings would collapse (uniq) to a single id and slip under
    # MAX_MULTIPLE_VALUES, silently accepting a paste the guard exists
    # to reject.
    def test_too_many_herbaria_values_rejected_before_resolution
      login
      herbarium = herbaria(:nybg_herbarium)
      too_many = Array.new(60) { herbarium.name }.join("\n")
      params = { herbaria: too_many }

      assert_nothing_raised do
        post(:create, params: { query_observations: params })
      end

      assert_redirected_to(action: :new)
      assert_flash_error(
        :runtime_search_too_many_values,
        field: :query_herbaria.l.humanize, count: 60,
        max: Searchable::MatchGuards::MAX_MULTIPLE_VALUES
      )
    end

    # ---------------------------------------------------------------
    #  Names lookup id-substitution (between MAX_MULTIPLE_VALUES and
    #  MAX_NAME_LOOKUP_VALUES): resolve to ids instead of rejecting
    # ---------------------------------------------------------------

    def test_names_lookup_over_threshold_resolves_to_ids
      login
      test_names = create_test_names(60)
      lookup = test_names.map(&:text_name).join("\n")
      params = { names: { lookup: lookup } }

      post(:create, params: { query_observations: params })

      assert_response(:redirect)
      redirect_params = parse_redirect_names_params
      assert_equal(test_names.map { |n| n.id.to_s }.sort,
                   redirect_params["lookup"].sort,
                   "Redirect should carry resolved ids, not name text")
      assert_equal("false", redirect_params["include_synonyms"],
                   "Expansion modifier should be reset to false, since " \
                   "expansion is already baked into the resolved ids")
    end

    def test_names_lookup_over_threshold_resets_expansion_modifiers
      login
      test_names = create_test_names(60)
      lookup = test_names.map(&:text_name).join("\n")
      params = {
        names: {
          lookup: lookup,
          include_synonyms: "true",
          include_subtaxa: "true"
        }
      }

      post(:create, params: { query_observations: params })

      redirect_params = parse_redirect_names_params
      assert_equal("false", redirect_params["include_synonyms"])
      assert_equal("false", redirect_params["include_subtaxa"])
    end

    def test_names_lookup_at_or_under_threshold_not_resolved
      login
      test_names = create_test_names(50)
      lookup = test_names.map(&:text_name).join("\n")
      params = { names: { lookup: lookup } }

      post(:create, params: { query_observations: params })

      redirect_params = parse_redirect_names_params
      # Still the raw name text, not ids -- at the threshold, not over it.
      assert_equal(test_names.map(&:text_name).sort,
                   redirect_params["lookup"].sort)
    end

    def test_names_lookup_between_thresholds_that_fail_to_resolve
      login
      # None of these match anything, so resolution produces an empty
      # id list -- should still redirect (not error), matching the
      # existing silent-drop behavior for unmatched names.
      unmatched = (1..60).map { |i| "Nonexistent Taxon #{i}" }.join("\n")
      params = { names: { lookup: unmatched } }

      assert_nothing_raised do
        post(:create, params: { query_observations: params })
      end

      assert_response(:redirect)
    end

    private

    def create_test_names(count)
      (1..count).map do |i|
        Name.create!(
          text_name: "Testus namus#{i}",
          search_name: "Testus namus#{i}",
          sort_name: "Testus namus#{i}",
          display_name: "**__Testus namus#{i}__**",
          author: "",
          rank: "Species",
          deprecated: false,
          user: rolf
        )
      end
    end

    def parse_redirect_names_params
      uri = URI.parse(@response.redirect_url)
      Rack::Utils.parse_nested_query(uri.query)["names"]
    end
  end
end
