# frozen_string_literal: true

require("test_helper")

# Controller tests for search pages
class SearchControllerTest < FunctionalTestCase
  def test_advanced
    login
    [Name, Image, Observation].each do |model|
      get(
        :advanced,
        params: {
          search: {
            name: "Don't know",
            user: "myself",
            model: model.name.underscore,
            content: "Long pink stem and small pink cap",
            location: "Eastern Oklahoma"
          },
          commit: "Search"
        }
      )
      assert_response(:redirect)
      # Account for Observations being the home page
      route = model == Observation ? "" : model.to_s.downcase.pluralize
      assert_match(
        "http://test.host/#{route}?advanced_search=1",
        redirect_to_url
      )
    end
  end

  def test_advanced_search_content_filters
    login
    # Make sure all the right buttons and fields are present.
    get(:advanced)
    assert_select("input[type=radio]#content_filter_with_images_yes")
    assert_select("input[type=radio]#content_filter_with_images_no")
    assert_select("input[type=radio]#content_filter_with_images_")
    assert_select("input[type=radio]#content_filter_with_specimen_yes")
    assert_select("input[type=radio]#content_filter_with_specimen_no")
    assert_select("input[type=radio]#content_filter_with_specimen_")
    assert_select("input[type=radio]#content_filter_lichen_yes")
    assert_select("input[type=radio]#content_filter_lichen_no")
    assert_select("input[type=radio]#content_filter_lichen_")
    assert_select("input[type=text]#content_filter_region")
    assert_select("input[type=text]#content_filter_clade")

    params = {
      search: {
        model: "observation",
        user: "rolf"
      },
      content_filter: {
        with_images: "",
        with_specimen: "yes",
        lichen: "no",
        region: "California",
        clade: ""
      }
    }
    get(:advanced, params: params)
    query = QueryRecord.last.query
    assert_equal("", query.params[:with_images])
    assert_true(query.params[:with_specimen])
    assert_false(query.params[:lichen])
    assert_equal(["California"], query.params[:region])
    assert_equal("", query.params[:clade])
  end

  def test_pattern_search
    login
    params = { search: { pattern: "12", type: :observation } }
    get(:pattern, params: params)
    assert_redirected_to(observations_path(pattern: "12"))

    params = { search: { pattern: "34", type: :image } }
    get(:pattern, params: params)
    assert_redirected_to(images_path(pattern: "34"))

    params = { search: { pattern: "56", type: :name } }
    get(:pattern, params: params)
    assert_redirected_to(names_path(pattern: "56"))

    params = { search: { pattern: "78", type: :location } }
    get(:pattern, params: params)
    assert_redirected_to(locations_path(pattern: "78"))

    params = { search: { pattern: "90", type: :comment } }
    get(:pattern, params: params)
    assert_redirected_to(comments_path(pattern: "90"))

    params = { search: { pattern: "21", type: :project } }
    get(:pattern, params: params)
    assert_redirected_to(projects_path(pattern: "21"))

    params = { search: { pattern: "12", type: :species_list } }
    get(:pattern, params: params)
    assert_redirected_to(species_lists_path(pattern: "12"))

    params = { search: { pattern: "34", type: :user } }
    get(:pattern, params: params)
    assert_redirected_to(users_path(pattern: "34"))

    params = { search: { pattern: "34", type: :glossary_term } }
    get(:pattern, params: params)
    assert_redirected_to(glossary_terms_path(pattern: "34"))

    stub_request(:any, /google.com/)
    pattern =  "hexiexiva"
    params = { search: { pattern: pattern, type: :google } }
    target =
      "https://google.com/search?q=site%3Amushroomobserver.org+#{pattern}"
    get(:pattern, params: params)
    assert_redirected_to(target)

    params = { search: { pattern: "", type: :google } }
    get(:pattern, params: params)
    assert_redirected_to("/")

    params = { search: { pattern: "x", type: :nonexistent_type } }
    get(:pattern, params: params)
    assert_redirected_to("/")

    params = { search: { pattern: "", type: :observation } }
    get(:pattern, params: params)
    assert_redirected_to(observations_path)

    # Make sure this redirects to the index that lists all herbaria,
    # rather than the index that lists query results.
    params = { search: { pattern: "", type: :herbarium } }
    get(:pattern, params: params)
    assert_redirected_to(herbaria_path(flavor: :all))
  end
end
