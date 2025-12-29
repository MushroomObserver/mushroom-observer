# frozen_string_literal: true

require("test_helper")

# Tests which supplement controller/observations_controller_test.rb
class SearchIntegrationTest < CapybaraIntegrationTestCase
  def test_observations_search_form
    shroom = "Agaricus campestris"
    lichen = "Peltigera"
    lookup = "#{shroom}\n#{lichen}"
    location = locations(:burbank)

    login
    visit("/observations/search/new")
    within("#observations_search_form") do |form|
      assert_selector("#query_observations_names_lookup")
      form.fill_in("query_observations_names_lookup", with: lookup)
      # assert_selector("#query_observations_names_lookup", text: lookup)
      form.select("yes", from: "query_observations_names_include_synonyms")
      location.bounding_box.each do |key, val|
        form.fill_in("query_observations_in_box_#{key}", with: val)
      end
      form.select("no", from: "query_observations_lichen")

      first(:button, type: "submit").click
    end

    assert_no_selector("#flash_notices")
    assert_selector("#filters", text: shroom)
    assert_selector("#results", text: shroom)
    assert_no_selector("#results", text: lichen)
    assert_selector("#results", text: observations(:agaricus_campestris_obs).id)
  end

  def test_names_search_form
    lookup = "Chlorophyllum" # Has subtaxa, one misspelled, both have author

    login
    visit("/names/search/new")
    within("#names_search_form") do |form|
      assert_selector("#query_names_names_lookup")
      form.fill_in("query_names_names_lookup", with: lookup)
      form.select("yes", from: "query_names_names_include_synonyms")
      form.select("yes", from: "query_names_names_include_subtaxa")
      form.select("no", from: "query_names_names_exclude_original_names")
      form.select("yes", from: "query_names_has_author")
      form.select("include", from: "query_names_misspellings")

      first(:button, type: "submit").click
    end

    assert_no_selector("#flash_notices")
    assert_selector("#filters", text: lookup)
    assert_selector("#results", text: lookup)
    assert_no_selector("#results", text: names(:chlorophyllum).id)
    assert_selector("#results", text: names(:chlorophyllum_rachodes).id)
    assert_selector("#results", text: names(:chlorophyllum_rhacodes).id)
  end

  def test_locations_search_form
    Location.update_box_area_and_center_columns
    region = "California, USA"
    location = locations(:california)

    login
    visit("/locations/search/new")
    within("#locations_search_form") do |form|
      assert_selector("#query_locations_region")
      form.fill_in("query_locations_region", with: region)
      location.bounding_box.each do |key, val|
        form.fill_in("query_locations_in_box_#{key}", with: val)
      end

      first(:button, type: "submit").click
    end

    assert_no_selector("#flash_notices")
    assert_selector("#filters", text: region)
    assert_selector("#filters", text: location.bounding_box[:south])
    assert_selector("#results", text: locations(:burbank).text_name)
  end

  def test_projects_search_form
    members = users(:mary).login

    login
    visit("/projects/search/new")
    within("#projects_search_form") do |form|
      assert_selector("#query_projects_members")
      form.fill_in("query_projects_members", with: members)

      first(:button, type: "submit").click
    end

    assert_no_selector("#flash_notices")
    assert_selector("#filters", text: users(:mary).name)
    assert_selector("#results", text: projects(:two_list_project).title)
    assert_selector("#results", text: projects(:empty_project).title)
  end

  def test_observations_search_form_within_locations
    california = "California, USA"

    login
    visit("/observations/search/new")
    within("#observations_search_form") do |form|
      assert_selector("#query_observations_within_locations")
      form.fill_in("query_observations_within_locations", with: california)

      first(:button, type: "submit").click
    end

    assert_no_selector("#flash_notices")
    assert_selector("#filters", text: "within locations: #{california}")
    # Verify observations from California localities appear in results
    # Spot-check for observations from Burbank, Point Reyes, and Pasadena
    assert_selector("#results", text: "Burbank, California, USA")
    assert_selector("#results", text: "Point Reyes National Seashore")
    assert_selector("#results", text: "Pasadena, California, USA")
  end

  # Test multi-value species_list autocompleter in observations search
  def test_observations_search_form_with_species_lists
    list1 = species_lists(:first_species_list)
    list2 = species_lists(:another_species_list)

    login
    visit("/observations/search/new")

    within("#observations_search_form") do |form|
      # Expand the "connected" panel to reveal species_lists field
      find("[data-target='#observations_connected']").click

      # Wait for the panel to expand
      assert_selector("#query_observations_species_lists", visible: true)

      # Fill in the autocompleter with multiple values (newline-separated)
      form.fill_in("query_observations_species_lists",
                   with: "#{list1.title}\n#{list2.title}")

      # Simulate autocompleter setting the hidden IDs field
      form.find("#query_observations_species_lists_id", visible: :all).
        set("#{list1.id},#{list2.id}")

      first(:button, type: "submit").click
    end

    # Form submitted successfully - check filter shows the search term
    # (may have no results if fixture lists have no observations)
    assert_selector("#filters", text: list1.title)
  end

  # Test multi-value project autocompleter (project_lists) in obs search.
  # Note: project_lists filters by observations on species lists belonging to
  # those projects, so the filter displays species list names, not projects.
  def test_observations_search_form_with_project_lists
    # Use two_list_project which has associated species lists
    proj = projects(:two_list_project)
    list1 = species_lists(:query_first_list)

    login
    visit("/observations/search/new")

    within("#observations_search_form") do |form|
      # Expand the "connected" panel to reveal project_lists field
      find("[data-target='#observations_connected']").click

      # Wait for the panel to expand
      assert_selector("#query_observations_project_lists", visible: true)

      # Fill in the autocompleter with the project title
      form.fill_in("query_observations_project_lists", with: proj.title)

      # Simulate autocompleter setting the hidden IDs field
      form.find("#query_observations_project_lists_id", visible: :all).
        set(proj.id.to_s)

      first(:button, type: "submit").click
    end

    # Form submitted successfully - filter shows species list names from project
    assert_selector("#filters", text: "project lists:")
    assert_selector("#filters", text: list1.title)
  end

  # Test multi-value herbarium autocompleter in observations search
  def test_observations_search_form_with_herbaria
    herb1 = herbaria(:nybg_herbarium)
    herb2 = herbaria(:fundis_herbarium)

    login
    visit("/observations/search/new")

    within("#observations_search_form") do |form|
      # Expand the "connected" panel to reveal herbaria field
      find("[data-target='#observations_connected']").click

      # Wait for the panel to expand
      assert_selector("#query_observations_herbaria", visible: true)

      # Fill in the autocompleter with multiple values (newline-separated)
      form.fill_in("query_observations_herbaria",
                   with: "#{herb1.name}\n#{herb2.name}")

      # Simulate autocompleter setting the hidden IDs field
      form.find("#query_observations_herbaria_id", visible: :all).
        set("#{herb1.id},#{herb2.id}")

      first(:button, type: "submit").click
    end

    # Form submitted successfully - check filter shows the search term
    assert_selector("#filters", text: herb1.name)
  end

  # Test that hidden ID fields are prefilled when returning to search form
  def test_observations_search_form_prefills_hidden_id_field
    user1 = users(:rolf)
    user2 = users(:mary)

    login
    visit("/observations/search/new")

    within("#observations_search_form") do |form|
      # Fill in the autocompleter with multiple values
      form.fill_in("query_observations_by_users",
                   with: "#{user1.unique_text_name}\n#{user2.unique_text_name}")
      # Simulate autocompleter setting the hidden IDs field
      form.find("#query_observations_by_users_id", visible: :all).
        set("#{user1.id},#{user2.id}")

      first(:button, type: "submit").click
    end

    # Should have results
    assert_selector("#filters", text: user1.name)

    # Navigate back to the search form - session should preserve the query
    visit("/observations/search/new")

    within("#observations_search_form") do |form|
      # Verify textarea is prefilled with display names
      textarea = form.find("#query_observations_by_users", visible: :all)
      assert_includes(textarea.value, user1.unique_text_name)
      assert_includes(textarea.value, user2.unique_text_name)

      # Verify hidden ID field is prefilled (this was the bug)
      hidden_field = form.find("#query_observations_by_users_id", visible: :all)
      expected_ids = "#{user1.id},#{user2.id}"
      assert_equal(expected_ids, hidden_field.value,
                   "Hidden ID field should be prefilled with IDs")
    end
  end

  # Test that locations pattern search help is displayed
  def test_locations_pattern_search_help
    login
    visit("/locations/search")

    # Verify the help partial is rendered
    assert_selector("p", text: "Locations Searches")
    # Verify that pattern search help intro is shown
    assert_text("Your search string may contain terms")
    assert_text("Recognized variables include:")
    # Verify that pattern search terms are shown
    assert_text("region")
    assert_text("user")
    assert_text("created")
    assert_text("modified")
    assert_text("has_notes")
    assert_text("has_observations")
  end

  # TODO: Test that selecting an MO location from region autocompleter
  # fills box inputs. Needs manual verification first.
  # def test_region_autocompleter_fills_box_inputs; end

  # def test_species_lists_search_form; end

  # def test_herbaria_search_form; end
end
