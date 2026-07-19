# frozen_string_literal: true

require("test_helper")

class ObservationsControllerIndexTest < FunctionalTestCase
  tests ObservationsController

  def setup
    super
    # Must do this to get center lats saved on fixtures without lat/lng.
    Location.update_box_area_and_center_columns
  end

  ######## Index ################################################
  # Tests of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of index_active_params
  # miscellaneous tests using get(:index)

  # First, test that the index does not require login - AN 20230923
  def test_index_no_login
    # login
    get(:index)

    assert_response(:redirect)
  end

  # Regression for #4492: the top-nav `search-type` Stimulus controller
  # reads its help/form type lists as Array values, which Stimulus parses
  # as JSON. Phlexifying top_nav emitted the arrays space-joined ("a b")
  # instead of JSON-encoded, so JSON.parse threw and silently disabled the
  # advanced-search and help forms. The attributes must be valid JSON.
  def test_search_nav_stimulus_array_values_are_json
    login
    get(:index)

    node = css_select("#search_nav").first
    assert_not_nil(node, "search nav not rendered")
    %w[data-search-type-form-types-value
       data-search-type-help-types-value].each do |attr|
      parsed = JSON.parse(node[attr])
      assert_kind_of(Array, parsed, "#{attr} must be a JSON array")
      assert_includes(parsed, "observations", "#{attr} must list observations")
    end
  end

  BUNCH_OF_NAMES = Name.take(10)
  BUNCH_OF_REGIONS = [
    "Connecticut, USA",
    "Maine, USA",
    "Massachusetts, USA",
    "New Hampshire, USA",
    "New Jersey, USA",
    "New York, USA",
    "Pennsylvania, USA",
    "Rhode Island, USA",
    "Vermont, USA",
    "New Brunswick, Canada",
    "Newfoundland and Labrador, Canada",
    "Newfoundland, Canada",
    "Labrador, Canada",
    "Nova Scotia, Canada",
    "Ontario, Canada",
    "Prince Edward Island, Canada",
    "Quebec, Canada"
  ].freeze
  SUPERLONG_REGIONS = [
    "Across the street from C & O Restaurant, Charlottesville, Virginia, USA",
    "Rivanna River trail at the Woolen Mills, Charlottesville, Virginia, USA"
  ].freeze

  # Taken from actual obs query params for the Northeast Rare Fungi Challenge
  def big_obs_query_params
    { names: { lookup: [*BUNCH_OF_NAMES.map(&:id)] }, region: BUNCH_OF_REGIONS }
  end

  def long_obs_query_params
    { region: SUPERLONG_REGIONS }
  end

  def test_filter_caption_truncation_number_of_values
    login

    query = Query.lookup_and_save(:Observation, big_obs_query_params)
    get(:index, params: { q: @controller.q_param(query) })

    names_joined_trunc = BUNCH_OF_NAMES.first(3).map(&:text_name).join(", ")
    names_joined_trunc += ", ..."
    assert_select("#caption-truncated", text: /#{names_joined_trunc}/)

    regions_joined_trunc = BUNCH_OF_REGIONS.first(3).join(", ")
    regions_joined_trunc += ", ..."
    assert_select("#caption-truncated", text: /#{regions_joined_trunc}/)

    names_joined = BUNCH_OF_NAMES.map(&:text_name).join(", ")
    assert_select("#caption-full", text: /#{names_joined}/)

    regions_joined = BUNCH_OF_REGIONS.join(", ")
    assert_select("#caption-full", text: /#{regions_joined}/)
  end

  def test_filter_caption_truncation_length_of_string
    login

    query = Query.lookup_and_save(:Observation, long_obs_query_params)
    get(:index, params: { q: @controller.q_param(query) })

    regions_joined = SUPERLONG_REGIONS.join(", ")
    regions_joined_trunc = "#{regions_joined[0...97]}..."
    assert_select("#caption-truncated", text: /#{regions_joined_trunc}/)
    assert_select("#caption-full", text: /#{regions_joined}/)
  end

  def test_index_sorted_by_invalid_order
    by = "edibility"

    login

    get(:index, params: { by: by })
    assert_flash_text("Can't figure out how to sort Observations by :#{by}.")
  end

  def test_index_with_id
    obs = observations(:agaricus_campestris_obs)

    login
    get(:index, params: { id: obs.id })

    assert_page_title(:observations.ti)
    assert_select("body.observations__index", true)
    assert_select(
      "#results .rss-heading a[href ^= '/obs/#{obs.id}'] .rss-name",
      { text: obs.format_name.t.strip_html },
      "Index should open at the page that includes #{obs.format_name}"
    )
    assert_select(".pagination_numbers a", { text: "Previous" },
                  "Wrong page or display is missing a link to Previous page")
  end

  def test_index_query_no_matches
    query = Query.lookup(:Observation, id_in_set: "one")
    params = { q: @controller.q_param(query) }

    login
    get(:index, params:)
    assert_flash_error(:runtime_no_matches.t(type: :observation))
  end

  # `?page=999` on a result set with fewer than 999 pages should
  # redirect to the last valid page rather than render an empty
  # result-area. Implementation: `ApplicationController::Indexes
  # #redirect_past_last_page?`.
  def test_index_page_past_last_redirects_to_last_page
    login
    get(:index, params: { page: 999 })

    pagination = @controller.instance_variable_get(:@pagination_data)
    assert_operator(
      pagination.num_pages, :>=, 1,
      "Fixture needs at least one observation for this test to mean anything"
    )
    assert_redirected_to(action: :index, page: pagination.num_pages)
  end

  # Created in response to a bug seen in the wild
  # place_name isn't a param for Observation#index
  # but is an API param and a param for Observation#create
  def test_index_useless_param
    params = { place_name: "Burbank" }

    login
    get(:index, params: params)

    assert_page_title(:observations.ti)
  end

  def test_index_useless_param_page2
    params = { place_name: "Burbank", page: 2 }

    login
    get(:index, params: params)

    assert_page_title(:observations.ti)
    assert_select(".pagination_numbers a", { text: "Previous" },
                  "Wrong page or display is missing a link to Previous page")
  end

  # In response to a bug seen in the wild where this request
  # threw an error
  def test_index_undefined_location
    params = { where: "Oakfield%2C+Halifax%2C+Nova+Scotia%2C+Canada" }

    login
    get(:index, params: params)

    assert_response(:success)
  end

  # The pattern param is maintained only for backwards compatibility.
  # Should redirect to SearchController#pattern, which instantiates the
  # PatternSearch::Observation and then redirects here with :q param
  def test_index_pattern_param_redirected_to_search
    pattern = "Agaricus"

    login
    get(:index, params: { pattern: })
    assert_redirected_to(
      search_pattern_path(pattern_search: { pattern:, type: :observations })
    )
  end

  def setup_rolfs_index
    rolf.layout_count = 99
    rolf.save!
    login
  end

  def q_pattern(pattern)
    { q: { model: :Observation, pattern: } }
  end

  def q_name_params(pattern)
    {
      q: {
        model: :Observation,
        names: {
          lookup: pattern, include_synonyms: true, include_subtaxa: true
        }
      }
    }
  end

  def test_index_pattern_multiple_hits
    pattern = "Agaricus"
    params = q_name_params(pattern)

    setup_rolfs_index
    get(:index, params:)

    # Pattern search guesses this is a name query
    assert_page_title(:observations.ti)
    assert_displayed_filters("#{:query_names.l}: #{pattern}")

    count = Observation.pattern(pattern).count
    assert_results(text: /#{pattern}/i, count:)
  end

  def test_index_pattern1
    pattern = "Boletus edulis"
    params = q_name_params(pattern)

    setup_rolfs_index
    get(:index, params:)

    # Pattern search guesses this is a name query
    assert_page_title(:observations.ti)
    assert_displayed_filters("#{:query_names.l}: #{pattern}")

    count = Observation.pattern(pattern).count
    assert_results(text: /#{pattern}/i, count:)
    assert_not_empty(css_select('[id="context_nav"]').text, "Tabset is empty")
  end

  def test_index_pattern_page2
    pattern = "Boletus edulis"
    params = q_name_params(pattern).merge(page: 2)

    login
    get(:index, params:)

    # Pattern search guesses this is a name query
    assert_page_title(:observations.ti)
    assert_displayed_filters("#{:query_names.l}: #{pattern}")

    assert_not_empty(css_select('[id="context_nav"]').text, "Tabset is empty")
    assert_select(".pagination_numbers a", { text: "Previous" },
                  "Wrong page or display is missing a link to Previous page")
  end

  def test_index_filter_display_is_concise
    pattern = "Agrocybe arvalis" # There are two
    params = q_name_params(pattern)

    setup_rolfs_index
    # This is what search_controller sends for that pattern:
    get(:index, params:)
    assert_page_title(:observations.ti)
    assert_displayed_filters("#{:query_names.l}: #{pattern}")

    modifiers = "#{:query_include_synonyms.l}, #{:query_include_subtaxa.l}"
    filter_txt = "#{:query_names.l}: #{pattern}, #{modifiers}"
    # We print both truncated and non-truncated filter captions, and show/hide
    # via Stimulus, so the expected string will be duplicated.
    assert_equal(filter_txt + filter_txt,
                 css_select("#filters").text, "Filter text is wrong.")

    filter_txt_dup =
      "#{:query_names.l}: #{pattern}, #{pattern}, #{modifiers}"
    assert_not_equal(
      filter_txt_dup + filter_txt_dup,
      css_select("#filters").text,
      "Filter caption for 'Names' is repeating a text_name."
    )
  end

  def test_index_pattern_no_hits
    pattern = "no hits"
    params = q_pattern(pattern)

    login
    get(:index, params:)

    assert_empty(css_select('[id="context_nav"]').text,
                 "RH tabset should be empty when search has no hits")
    assert_page_title(:observations.ti)
  end

  def test_index_pattern_one_hit
    obs = observations(:two_img_obs)

    login
    get(:index, params: { pattern: obs.id })

    assert_match(/#{obs.id}/, redirect_to_url,
                 "Search with 1 hit should show the hit")
  end

  def test_index_look_alikes
    obs = observations(:owner_only_favorite_ne_consensus)
    name = obs.name
    look_alikes = Observation.joins(:namings).
                  where(namings: { name: name }).
                  where.not(name: name).count
    assert(look_alikes > 1, "Test needs different fixture")

    setup_rolfs_index
    get(:index, params: { look_alikes: "1", name: name.id })

    assert_page_title(:observations.ti)
    assert_displayed_filters("#{:query_names.l}: #{name.text_name}")
    assert_results(count: look_alikes)
  end

  def test_index_look_alikes_no_hits
    obs = observations(:strobilurus_diminutivus_obs)
    name = obs.name
    look_alikes = Observation.joins(:namings).
                  where(namings: { name: name }).
                  where.not(name: name).count
    assert(look_alikes.zero?, "Test needs different fixture")

    setup_rolfs_index
    get(:index, params: { look_alikes: "1", name: name.id })

    assert_response(:success)
    assert_page_title(:observations.ti)
    assert_results(count: look_alikes)
  end

  def test_index_related_taxa
    name = names(:tremella_mesenterica)
    parent = name.parents.first
    obss_of_related_taxa =
      Observation.where(
        name: Name.where(Name[:text_name] =~ /#{parent.text_name} /).or(
          Name.where(Name[:classification] =~ /: _#{parent.text_name}_/)
        ).or(Name.where(id: parent.id))
      )

    setup_rolfs_index
    get(:index, params: { related_taxa: "1", name: name.text_name })
    assert_page_title(:observations.ti)
    assert_displayed_filters("#{:query_names.l}: #{parent.text_name}")
    assert_results(count: obss_of_related_taxa.count)
  end

  def test_index_name
    name = names(:fungi)
    ids = Observation.where(name: name).map(&:id)
    assert(ids.length.positive?, "Test needs different fixture for 'name'")
    params = { name: name }

    login("zero") # Has no observations
    get(:index, params: params)

    assert_response(:success)
    assert_page_title(:observations.ti)
    assert_displayed_filters("#{:query_names.l}: #{name.text_name}")
    ids.each do |id|
      assert_select(
        "a:match('href', ?)", %r{^/obs/#{id}}, true,
        "Observations of Name should link to each Observation of Name"
      )
    end
  end

  def test_index_user_by_known_user
    # Make sure fixtures are still okay
    obs = observations(:coprinus_comatus_obs)
    assert_not_nil(obs.rss_log_id)
    assert_not_nil(obs.thumb_image_id)
    user = rolf
    assert(
      user.layout_count >= user.observations.size,
      "User must be able to display all rolf's Observations in a single page"
    )

    test_show_owner_id_noone_logged_in

    login(user.login)
    get(:index, params: { by_user: user.id })

    assert_page_title(:observations.ti)
    assert_displayed_filters("#{:query_by_users.l}: #{user.name}")

    assert_select(
      "#results img.image_#{obs.thumb_image_id}",
      true,
      "Observation thumbnail should display although this is not an rss_log"
    )
    assert_results(text: /\S+/, # ignore links in buttons
                   count: Observation.where(user: user).count)
  end

  def test_show_owner_id_noone_logged_in
    logout
    get(
      :show, params: { id: observations(:owner_only_favorite_ne_consensus).id }
    )
    assert_select("#owner_naming", { count: 0 },
                  "Do not show Observer ID when nobody logged in")
  end

  def test_index_user_unknown_user
    user = observations(:minimal_unknown_obs)

    login
    get(:index, params: { by_user: user })

    assert_equal(users_url, redirect_to_url, "Wrong page")
    assert_flash_text(:runtime_object_not_found.l(type: :user.l, id: user.id))
  end

  def test_index_location_with_observations
    location = locations(:obs_default_location)
    params = { location: location.id }

    login
    get(:index, params: params)

    assert_page_title(:observations.ti)
    assert_displayed_filters(
      "#{:query_within_locations.l}: #{location.display_name}"
    )
  end

  def test_index_location_without_observations
    location = locations(:unused_location)
    params = { location: location }
    flash_matcher = Regexp.new(
      Regexp.escape_except_spaces(
        :runtime_no_matches.t(type: :observation)
      )
    )

    login
    get(:index, params: params)

    assert_response(:success)
    assert_flash(flash_matcher)
    assert_page_title(:observations.ti)
  end

  def test_index_location_with_nonexistent_location
    location = "non-existent"
    params = { location: location }
    flash_matcher = Regexp.new(
      Regexp.escape_except_spaces(
        :runtime_object_not_found.t(type: :location, id: location)
      )
    )

    login
    get(:index, params: params)

    assert_flash(flash_matcher)
    assert_redirected_to(locations_path)
  end

  def test_index_within_location_california
    location = locations(:california)
    q_param = { model: :Observation, within_locations: location.id }

    login
    get(:index, params: { q: q_param })

    assert_page_title(:observations.ti)
    assert_displayed_filters(
      "#{:query_within_locations.l}: #{location.display_name}"
    )
    cali_locs = Location.where(Location[:name].matches("%California, USA%"))
    # This is the count of obs associated specifically with each California
    # location. The "within" scope should retrieve all of them (and currently,
    # from most of Nevada too, if we have any - because it's "in_box").
    count = Observation.locations([cali_locs]).count
    assert_results(count:)
  end

  # Regression: query_from_q_param_hash must call symbolize_keys on
  # to_unsafe_hash before passing to Query.lookup. Without it, string-keyed
  # params from the URL bypass the attribute slice and produce a query with
  # no filter, or cause a TypeError in Ruby 3.4+.
  # This is the param format produced by clicking "Show Observations at
  # this Location" from a location show page.
  def test_index_q_param_hash_with_locations
    location = locations(:burbank)
    q_param = { model: "Observation", locations: [location.id] }

    login
    get(:index, params: { q: q_param })

    assert_response(:success,
                    "Expected success — Integer NoMethodError means " \
                    "symbolize_keys is missing in query_from_q_param_hash")
    assert_page_title(:observations.ti, "Should be on the observations index")
    assert_displayed_filters(location.display_name,
                             "Location filter should appear in #filters")
    assert_results(count: Observation.locations(location).count)
  end

  def test_index_where
    location = locations(:obs_default_location)

    login
    get(:index, params: { where: location.name })
    assert_page_title(:observations.ti)
    assert_displayed_filters(
      "#{:query_search_where.l}: #{location.display_name}"
    )
    q = @controller.q_param
    assert_select("a[href^='#{new_location_path(q:, where: location.name)}']")
  end

  def test_index_where_page2
    location = locations(:obs_default_location)

    login
    get(:index, params: { where: location.name, page: 2 })
    assert_select(".pagination_numbers a", { text: "Previous" },
                  "Wrong page or display is missing a link to Previous page")
    assert_page_title(:observations.ti)
    assert_displayed_filters(
      "#{:query_search_where.l}: #{location.display_name}"
    )
    assert_not_empty(css_select('[id="context_nav"]').text, "Tabset is empty")
  end

  def test_index_prev_next_page_links
    location = locations(:obs_default_location)
    query = Query.lookup_and_save(:Observation, locations: [location])
    q = @controller.q_param(QueryRecord.last.query)
    o_loc = query.results

    login
    # Test index links lose the id param on next/prev page and goto_page
    get(:index, params: { id: o_loc.third.id, q: })

    # Build expected encoded strings using Hash#to_query for readability
    q_model = { q: { model: "Observation" } }.to_query
    q_locations = { q: { locations: nil } }.to_query.sub("=", "") # Just the key

    # Check that next page link exists with correct params (order-agnostic)
    assert_select("a.next_page_link") do |links|
      href = links.first["href"]
      assert_includes(href, "page=2", "Next link should have page=2")
      assert_includes(href, q_model,
                      "Next link should have q[model]=Observation")
      assert_includes(href, q_locations, "Next link should have q[locations]")
    end
    # On page 1, prev link should be disabled (has opacity-0 class)
    assert_select("a.prev_page_link.disabled.opacity-0")
    assert_select("form.page_input[action='#{observations_url}']")
    assert_select("input[type='hidden'][name='q[model]'][value='Observation']")
  end

  # Regression test for https://github.com/MushroomObserver/mushroom-observer/pull/3528
  # Array params like by_users=[1,2,3] must be preserved when paginating
  # Full flow: search with multiple users -> paginate -> search form prefilled
  def test_index_pagination_preserves_array_params
    # Use three users with enough combined observations to trigger pagination
    user1 = users(:dick)   # 39 obs
    user2 = users(:rolf)   # 14 obs
    user3 = users(:mary)   # 7 obs = 60 total, exceeds default page size
    query = Query.lookup_and_save(:Observation,
                                  by_users: [user1.id, user2.id, user3.id])
    q = @controller.q_param(query)

    login
    get(:index, params: { q: q })

    # Build expected encoded strings using Hash#to_query for readability
    by_user_1 = { q: { by_users: [user1.id] } }.to_query
    by_user_2 = { q: { by_users: [user2.id] } }.to_query
    by_user_3 = { q: { by_users: [user3.id] } }.to_query

    # Check that next page link preserves ALL array values
    assert_select("a.next_page_link") do |links|
      href = links.first["href"]
      assert_includes(href, by_user_1,
                      "Next link should preserve first by_users value")
      assert_includes(href, by_user_2,
                      "Next link should preserve second by_users value")
      assert_includes(href, by_user_3,
                      "Next link should preserve third by_users value")
    end

    # Also check the page input form has hidden fields for all three values
    assert_select("input[type='hidden'][name='q[by_users][]']" \
                  "[value='#{user1.id}']")
    assert_select("input[type='hidden'][name='q[by_users][]']" \
                  "[value='#{user2.id}']")
    assert_select("input[type='hidden'][name='q[by_users][]']" \
                  "[value='#{user3.id}']")

    # Search form prefilling is tested in
    # test/controllers/observations/search_controller_test.rb
  end

  def test_index_project
    project = projects(:bolete_project)

    login
    get(:index, params: { project: project.id })

    assert_response(:success)
    assert_page_title(:observations.ti)
  end

  # Covers the `return unless (project = find_or_goto_index(...))`
  # bail-out in `ObservationsController::Index#project` (L169).
  def test_index_project_with_unknown_id_redirects
    login
    get(:index, params: { project: 999_999_999 })

    assert_redirected_to(projects_path)
  end

  def test_index_project_banner_from_query_param
    project = projects(:eol_project)

    login
    get(:index, params: {
          q: { model: "Observation", projects: [project.id] }
        })

    assert_response(:success)
    assert_equal(project.id, assigns(:project)&.id,
                 "@project should be set from query params")
  end

  def test_index_project_without_observations
    project = projects(:empty_project)

    login
    get(:index, params: { project: project.id })

    assert_response(:success)
    assert_page_title(:observations.ti)
    assert_flash_text(:runtime_no_matches.l(type: :observation))
  end

  def test_index_species_list
    spl = species_lists(:unknown_species_list)

    login
    get(:index, params: { species_list: spl.id })

    assert_response(:success)
    assert_page_title(:observations.ti)
    assert_displayed_filters("#{:species_lists.l}: #{spl.title}")
  end

  # Covers the `return unless (spl = find_or_goto_index(...))`
  # bail-out in `ObservationsController::Index#species_list` (L181).
  def test_index_species_list_with_unknown_id_redirects
    login
    get(:index, params: { species_list: 999_999_999 })

    assert_redirected_to(species_lists_path)
  end

  def test_index_species_list_without_observations
    spl = species_lists(:first_species_list)

    login
    get(:index, params: { species_list: spl.id })

    assert_response(:success)
    assert_page_title(:observations.ti)
    assert_flash_text(:runtime_no_matches.l(type: :observation))
  end

  # Prove that lichen content_filter works on observations
  def test_index_with_lichen_filter_only_lichens
    user = users(:lichenologist)

    login(user.name)
    get(:index)

    results = @controller.instance_variable_get(:@objects)

    assert(results.many?)
    assert(results.all? { |result| result.lifeform.include?("lichen") },
           "All results should be lichen-ish")
  end

  def test_index_with_lichen_filter_hide_lichens
    user = users(:antilichenologist)

    login(user.name)
    get(:index)

    results = @controller.instance_variable_get(:@objects)

    assert(results.many?)
    assert(results.none? { |result| result.lifeform.include?(" lichen ") },
           "No results should be lichens")
  end

  def test_index_with_region_filter
    observations_in_region =
      Observation.reorder(id: :asc).region("California, USA")

    user = users(:californian)
    # Make sure the fixture is still okay
    assert_equal({ region: "California, USA" }, user.content_filter)
    assert(user.layout_count >= observations_in_region.size,
           "User must be able to display search results in a single page.")

    login(user.name)
    get(:index)

    results = @controller.instance_variable_get(:@objects).sort_by(&:id)
    assert_obj_arrays_equal(observations_in_region, results)
  end

  def test_index_return_to_cookie_is_under_limit
    query = @controller.create_query(:Observation, **PARAMS_UNDER_LIMIT)
    get(:index, params: { q: query.q_param })
    assert_not_nil(session["return-to"])
    assert_match(query_string(query.q_param), session["return-to"])

    query = @controller.create_query(:Observation, **NERFC_QUERY_PARAMS)
    get(:index, params: { q: query.q_param })
    assert_nil(session["return-to"])
  end

  PARAMS_UNDER_LIMIT =
    { names: {
        lookup: ["Agaricus campestris"],
        include_synonyms: true,
        include_subtaxa: true
      },
      region: "Massachusetts, USA",
      has_images: true }.freeze

  NERFC_QUERY_PARAMS =
    { names: {
        lookup:
          ["Amanita ristichii",
           "Boletus purpureorubellus",
           "Butyriboletus billieae",
           "Entoloma indigoferum",
           "Caloboletus peckii",
           "Clavulinopsis appalachiensis",
           "Dendrocollybia racemosa",
           "Echinodontium ballouii",
           "Entoloma flavoviride",
           "Helvella palustris",
           "Hodophilus peckianus",
           "Hypocreopsis rhododendri",
           "Psathyrella epimyces",
           "Pseudofistulina radicata",
           "Squamanita imbachii",
           "Squamanita umbonata",
           "Tricholoma apium",
           "Tricholoma grave",
           "Underwoodia columnaris",
           "Volvariella surrecta",
           "Wynnea sparassoides"]
      },
      region:
      ["Connecticut, USA",
       "Maine, USA",
       "Massachusetts, USA",
       "New Hampshire, USA",
       "New Jersey, USA",
       "New York, USA",
       "Pennsylvania, USA",
       "Rhode Island, USA",
       "Vermont, USA",
       "New Brunswick, Canada",
       "Newfoundland and Labrador, Canada",
       "Newfoundland, Canada",
       "Labrador, Canada",
       "Nova Scotia, Canada",
       "Eastern Ontario, Canada",
       "Prince Edward Island, Canada",
       "Quebec, Canada"] }.freeze
end
