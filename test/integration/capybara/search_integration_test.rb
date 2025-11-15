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
      form.select("either", from: "query_names_misspellings")

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

  # def test_species_lists_search_form; end

  # def test_herbaria_search_form; end
end
