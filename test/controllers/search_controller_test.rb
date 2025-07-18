# frozen_string_literal: true

require("test_helper")

# Controller tests for search pages
class SearchControllerTest < FunctionalTestCase
  def test_advanced
    login
    # Image advanced search retired 2021
    [Name, Observation].each do |model|
      get(
        :advanced,
        params: {
          search: {
            search_name: "Don't know",
            search_user: "myself",
            model: model.name.underscore,
            search_content: "Long pink stem and small pink cap",
            search_where: "Eastern Oklahoma"
          },
          commit: "Search"
        }
      )
      assert_response(:redirect)
      route = model.to_s.downcase.pluralize
      assert_match(
        "http://test.host/#{route}?advanced_search=1",
        redirect_to_url
      )
    end
  end

  def test_advanced_provisional_name
    login
    get(:advanced,
        params: {
          search: {
            search_name: 'Cortinarius "sp-IN34"',
            search_user: "",
            model: "name",
            search_content: "",
            search_where: ""
          },
          commit: "Search"
        })
    assert_response(:redirect)
    query = QueryRecord.find(redirect_to_url.split("=")[-1].dealphabetize)
    assert_match(names(:provisional_name).text_name, query.description)
  end

  def test_advanced_search_content_filters
    login
    # Make sure all the right buttons and fields are present.
    get(:advanced)
    assert_select("input[type=radio]#content_filter_has_images_yes")
    assert_select("input[type=radio]#content_filter_has_images_no")
    assert_select("input[type=radio]#content_filter_has_images_")
    assert_select("input[type=radio]#content_filter_has_specimen_yes")
    assert_select("input[type=radio]#content_filter_has_specimen_no")
    assert_select("input[type=radio]#content_filter_has_specimen_")
    assert_select("input[type=radio]#content_filter_lichen_yes")
    assert_select("input[type=radio]#content_filter_lichen_no")
    assert_select("input[type=radio]#content_filter_lichen_")
    assert_select("input[type=text]#content_filter_region")
    assert_select("input[type=text]#content_filter_clade")

    params = {
      search: {
        model: "observation",
        search_user: users(:rolf).unique_text_name,
        search_user_id: users(:rolf).id
      },
      content_filter: {
        has_images: "",
        has_specimen: "yes",
        lichen: "no",
        region: "California",
        clade: ""
      }
    }
    get(:advanced, params: params)
    query = QueryRecord.last.query
    q = QueryRecord.last.id.alphabetize
    assert_redirected_to(observations_path(advanced_search: 1, q:))
    assert_true(query.num_results.positive?)
    assert_equal("", query.params[:has_images])
    assert_true(query.params[:has_specimen])
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
    assert_redirected_to(herbaria_path)
  end
end
