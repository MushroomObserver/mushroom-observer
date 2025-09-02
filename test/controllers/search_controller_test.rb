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
    # query = QueryRecord.find(redirect_to_url.split("=")[-1].dealphabetize)
    query_string = redirect_to_url.split("advanced_search=1&")[1]
    assert_match("Cortinarius", query_string)
    assert_match("IN34", query_string)
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
    q = @controller.q_param(query)
    assert_redirected_to(observations_path(advanced_search: 1, q:))
    assert_true(query.num_results.positive?)
    assert_equal("", query.params[:has_images])
    assert_true(query.params[:has_specimen])
    assert_false(query.params[:lichen])
    assert_equal(["California"], query.params[:region])
    assert_equal("", query.params[:clade])
  end

  def test_pattern_search_redirects_to_controllers_with_q
    login

    pattern = "12"

    # Test basic pattern for all the models with pattern queries/scopes.
    SearchController::PATTERN_SEARCHABLE_MODELS.each do |model|
      model_name = model.to_s.singularize.camelize.to_sym
      params = { pattern_search: { pattern:, type: model } }
      get(:pattern, params:)

      assert_redirected_to(
        send(:"#{model}_path", q: { model: model_name, pattern: })
      )

      assert_equal(model, @request.session[:search_type])
      assert_equal(pattern, @request.session[:pattern])

      # Increment to keep this unpredictable
      pattern = (pattern.to_i + 9).to_s
    end
  end

  def test_pattern_search_invalid_redirects_to_indexes
    params = { pattern_search: { pattern: "x", type: :nonexistent_type } }
    get(:pattern, params:)
    assert_redirected_to("/")

    params = { pattern_search: { pattern: "x", type: nil } }
    get(:pattern, params:)
    assert_redirected_to("/")

    params = { pattern_search: { pattern: "", type: :observations } }
    get(:pattern, params:)
    assert_redirected_to(observations_path)

    # Make sure this redirects to the index that lists all herbaria,
    # rather than the index that lists query results.
    params = { pattern_search: { pattern: "", type: :herbaria } }
    get(:pattern, params:)
    assert_redirected_to(herbaria_path)
  end

  def test_pattern_search_matching_an_id_redirects_to_show
    login

    SearchController::PATTERN_SEARCHABLE_MODELS.each do |model|
      model_name = model.to_s.singularize.camelize.to_sym
      id = model_name.to_s.constantize.last.id
      params = { pattern_search: { pattern: id, type: model } }
      get(:pattern, params:)

      show_path = :"#{model.to_s.singularize}_path"
      assert_redirected_to(
        send(show_path, id:)
      )
    end
  end

  def test_pattern_search_matching_title_redirects_to_show
    login

    models = SearchController::PATTERN_SEARCHABLE_MODELS.dup
    models.each do |model|
      model_name = model.to_s.singularize.camelize.to_sym
      last = model_name.to_s.constantize.last
      next unless last.respond_to?(:title)

      title = last.title
      id = last.id
      params = { pattern_search: { pattern: title, type: model } }
      get(:pattern, params:)

      show_path = :"#{model.to_s.singularize}_path"
      assert_redirected_to(send(show_path, id:))
    end
  end

  def test_pattern_search_flashes_term_errors
    login
    params = { pattern_search: { pattern: "help:me", type: :names } }
    get(:pattern, params:)
    assert_redirected_to(names_path(q: { model: :Name }))
    assert_flash_error("Unexpected term")
  end

  def test_index_pattern_bad_pattern
    pattern = { error: "" }

    login
    get(:pattern, params: { pattern_search: { pattern:, type: :observations } })

    assert_redirected_to(
      observations_path(q: { model: :Observation }),
      "Bad pattern in obs search should render blank obs index"
    )
  end

  def test_pattern_search_from_needs_naming
    pattern = "Briceland"
    params = { pattern_search: { pattern:, type: :observations },
               needs_naming: rolf }

    login
    get(:pattern, params:)

    assert_redirected_to(
      identify_observations_path(q: { model: :Observation, pattern: }),
      "Pattern in search from obs_needing_ids should render " \
      "obs_needing_ids"
    )
  end

  def test_pattern_search_from_needs_naming_bad_pattern
    pattern = { error: "" }
    params = { pattern_search: { pattern:, type: :observations },
               needs_naming: rolf }

    login
    get(:pattern, params:)

    assert_redirected_to(
      identify_observations_path(q: { model: :Observation }),
      "Bad pattern in search from obs_needing_ids should render " \
      "obs_needing_ids"
    )
  end

  def test_pattern_search_redirects_to_google
    login
    stub_request(:any, /google.com/)
    pattern =  "hexiexiva"
    params = { pattern_search: { pattern: pattern, type: :google } }
    target =
      "https://google.com/search?q=site%3Amushroomobserver.org+#{pattern}"
    get(:pattern, params:)
    assert_redirected_to(target)

    params = { pattern_search: { pattern: "", type: :google } }
    get(:pattern, params:)
    assert_redirected_to("/")
  end

  def test_id_pattern_redirects_to_show_page
    obs = Observation.first
    params = { pattern_search: { pattern: obs.id, type: :observations } }
    get(:pattern, params:)
    assert_redirected_to(observation_path(obs.id))

    name = names(:agaricus)
    params = { pattern_search: { pattern: name.id, type: :names } }
    get(:pattern, params:)
    assert_redirected_to(name_path(name.id))

    user = users(:rolf)
    params = { pattern_search: { pattern: user.id, type: :users } }
    get(:pattern, params:)
    assert_redirected_to(user_path(user.id))
    # User email should work too
    params = { pattern_search: { pattern: user.email, type: :users } }
    get(:pattern, params:)
    assert_redirected_to(user_path(user.id))
  end
end
