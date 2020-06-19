require "test_helper"

class SearchControllerTest < FunctionalTestCase

  def test_advanced_search_form
    [Name, Image, Observation].each do |model|
      post(
        "advanced_search_form",
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
      assert_match(%r{#{ model.show_controller }/advanced_search},
                   redirect_to_url)
    end
  end

  def test_pattern_search
    params = { search: { pattern: "12", type: :observation } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :observations, action: :observation_search,
                         pattern: "12")

    params = { search: { pattern: "34", type: :image } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :images, action: :image_search,
                         pattern: "34")

    params = { search: { pattern: "56", type: :name } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :names, action: :name_search,
                         pattern: "56")

    params = { search: { pattern: "78", type: :location } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :locations, action: :location_search,
                         pattern: "78")

    params = { search: { pattern: "90", type: :comment } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :comments, action: :comment_search,
                         pattern: "90")

    params = { search: { pattern: "12", type: :species_list } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :species_lists,
                         action: :species_list_search,
                         pattern: "12")

    params = { search: { pattern: "34", type: :user } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :users, action: :user_search,
                         pattern: "34")

    stub_request(:any, /google.com/)
    pattern =  "hexiexiva"
    params = { search: { pattern: pattern, type: :google } }
    target =
      "https://google.com/search?q=site%3Amushroomobserver.org+#{pattern}"
    get(:pattern_search, params)
    assert_redirected_to(target)

    params = { search: { pattern: "", type: :google } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :rss_logs, action: :list_rss_logs)

    params = { search: { pattern: "x", type: :nonexistent_type } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :rss_logs, action: :list_rss_logs)

    params = { search: { pattern: "", type: :observation } }
    get(:pattern_search, params)
    assert_redirected_to(controller: :observations, action: :list_observations)
  end

end
