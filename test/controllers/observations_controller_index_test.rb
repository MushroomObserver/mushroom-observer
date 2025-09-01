# frozen_string_literal: true

require("test_helper")

class ObservationsControllerIndexTest < FunctionalTestCase
  tests ObservationsController

  def setup
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

  def test_index_with_non_default_sort
    check_index_sorting
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

    assert_template("shared/_matrix_box")
    assert_page_title(:OBSERVATIONS.l)
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

  # Created in response to a bug seen in the wild
  # place_name isn't a param for Observation#index
  # but is an API param and a param for Observation#create
  def test_index_useless_param
    params = { place_name: "Burbank" }

    login
    get(:index, params: params)

    assert_page_title(:OBSERVATIONS.l)
  end

  def test_index_useless_param_page2
    params = { place_name: "Burbank", page: 2 }

    login
    get(:index, params: params)

    assert_page_title(:OBSERVATIONS.l)
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

  def test_index_advanced_search_name_and_location_multiple_hits
    name = "Agaricus"
    location = "California"
    expected_hits = Observation.where(Observation[:text_name] =~ name).
                    where(Observation[:where] =~ location)

    login
    get(:index,
        params: { search_name: name, search_where: location,
                  advanced_search: true })

    assert_response(:success)
    assert_results(count: expected_hits.count)
    assert_page_title(:OBSERVATIONS.l)
    assert_displayed_filters("#{:query_search_name.l}: #{name}")
    assert_displayed_filters("#{:query_search_where.l}: #{location}")
  end

  def test_index_advanced_search_name_one_hit
    obs = observations(:strobilurus_diminutivus_obs)
    search_string = obs.text_name
    query = Query.lookup_and_save(:Observation, search_name: search_string)
    assert(query.results.one?,
           "Test needs a string that has exactly one hit")

    login
    params = { q: @controller.q_param(query), advanced_search: true }
    get(:index, params:)

    assert_match(/#{obs.id}/, redirect_to_url,
                 "Advanced Search with 1 hit should show the hit")
  end

  def oklahoma_query
    Query.lookup_and_save(
      :Observation, search_name: "Don't know",
                    search_user: "myself",
                    search_content: "Long pink stem and small pink cap",
                    search_where: "Eastern Oklahoma"
    )
  end

  def test_index_advanced_search_no_hits
    query = oklahoma_query

    login
    params = { q: @controller.q_param(query), advanced_search: true }
    get(:index, params:)

    assert_flash_text(:runtime_no_matches.l(type: :observations.l))
    assert_page_title(:OBSERVATIONS.l)
  end

  def advanced_search_params
    {
      advanced_search: true,
      search_name: "Fungi",
      search_where: "String in notes"
    }.freeze
  end

  def test_index_advanced_search_notes1
    login
    get(:index, params: advanced_search_params)

    assert_response(:success)
    assert_select(
      "#results a", false,
      "There should be no results when string is missing from notes."
    )
    assert_flash_text(:runtime_no_matches.l(type: :observations.l))
    assert_page_title(:OBSERVATIONS.l)
  end

  # We currently no longer allow searching location notes.
  def test_index_advanced_search_notes3
    # Add string to notes, make sure it is actually added.
    login("rolf")
    loc = locations(:burbank)
    loc.notes = "blah blah blahString in notesblah blah blah"
    loc.save
    loc.reload
    assert(loc.notes.to_s.include?("String in notes"))

    login
    get(:index, params: advanced_search_params)

    assert_response(:success)
    assert_select(
      "#results a", false,
      "There should be no results even when notes include search string."
    )
    assert_flash_text(:runtime_no_matches.l(type: :observations.l))
    assert_page_title(:OBSERVATIONS.l)
  end

  def test_index_advanced_search_error
    query_no_conditions = Query.lookup_and_save(:Observation)

    login
    params = { q: @controller.q_param(query_no_conditions),
               advanced_search: true }
    get(:index, params:)

    assert_flash_error(:runtime_no_conditions.l)
    assert_redirected_to(
      search_advanced_path,
      "Advanced Search should reload form if it throws an error"
    )
  end

  def test_index_pattern_search_help
    login
    get(:index, params: { pattern: "help:me" })

    assert_flash_error
    assert_match(/unexpected term/i, @response.body)
  end

  def setup_rolfs_index
    rolf.layout_count = 99
    rolf.save!
    login
  end

  def test_index_pattern_multiple_hits
    pattern = "Agaricus"

    setup_rolfs_index
    get(:index, params: { pattern: pattern })

    # Pattern search guesses this is a name query
    assert_page_title(:OBSERVATIONS.l)
    assert_displayed_filters("#{:query_names.l}: #{pattern}")

    count = Observation.pattern(pattern).count
    assert_results(text: /#{pattern}/i, count:)
  end

  def test_index_pattern_needs_naming_with_filter
    pattern = "Briceland"

    setup_rolfs_index
    get(:index, params: { pattern: pattern, needs_naming: rolf })

    assert_match(/^#{identify_observations_url}/, redirect_to_url,
                 "Wrong page. Should redirect to #{:obs_needing_id.l}")
  end

  def test_index_pattern1
    pattern = "Boletus edulis"

    setup_rolfs_index
    get(:index, params: { pattern: pattern })

    # Pattern search guesses this is a name query
    assert_page_title(:OBSERVATIONS.l)
    assert_displayed_filters("#{:query_names.l}: #{pattern}")

    count = Observation.pattern(pattern).count
    assert_results(text: /#{pattern}/i, count:)
    assert_not_empty(css_select('[id="context_nav"]').text, "Tabset is empty")
  end

  def test_index_pattern_page2
    pattern = "Boletus edulis"

    login
    get(:index, params: { pattern: pattern, page: 2 })

    # Pattern search guesses this is a name query
    assert_page_title(:OBSERVATIONS.l)
    assert_displayed_filters("#{:query_names.l}: #{pattern}")

    assert_not_empty(css_select('[id="context_nav"]').text, "Tabset is empty")
    assert_select(".pagination_numbers a", { text: "Previous" },
                  "Wrong page or display is missing a link to Previous page")
  end

  def test_index_filter_display_is_concise
    pattern = "Agrocybe arvalis" # There are two

    setup_rolfs_index
    get(:index, params: { pattern: pattern })
    assert_page_title(:OBSERVATIONS.l)
    assert_displayed_filters("#{:query_names.l}: #{pattern}")

    filter_txt = "#{:query_names.l}: #{pattern}, with synonyms, with subtaxa"
    assert_equal(filter_txt + filter_txt,
                 css_select("#filters").text, "Filter text is wrong.")

    filter_txt_dup =
      "#{:query_names.l}: #{pattern}, #{pattern}, with synonyms, with subtaxa"
    assert_not_equal(
      filter_txt_dup + filter_txt_dup,
      css_select("#filters").text,
      "Filter caption for 'Names' is repeating a text_name."
    )
  end

  def test_index_pattern_no_hits
    pattern = "no hits"

    login
    get(:index, params: { pattern: pattern })

    assert_empty(css_select('[id="context_nav"]').text,
                 "RH tabset should be empty when search has no hits")
    assert_page_title(:OBSERVATIONS.l)
  end

  def test_index_pattern_one_hit
    obs = observations(:two_img_obs)

    login
    get(:index, params: { pattern: obs.id })

    assert_match(/#{obs.id}/, redirect_to_url,
                 "Search with 1 hit should show the hit")
  end

  def test_index_pattern_bad_pattern
    pattern = { error: "" }

    login
    get(:index, params: { pattern: pattern })

    assert_response(:success)
    assert_flash_error
    assert_displayed_title("")
    assert_select("#results", { text: "" }, "There should be no results")
  end

  def test_index_pattern_bad_pattern_from_needs_naming
    pattern = { error: "" }

    login
    get(:index, params: { pattern: pattern, needs_naming: rolf })

    assert_redirected_to(
      identify_observations_path,
      "Bad pattern in search from obs_needing_ids should render " \
      "obs_needing_ids"
    )
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

    assert_page_title(:OBSERVATIONS.l)
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
    assert_page_title(:OBSERVATIONS.l)
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
    assert_page_title(:OBSERVATIONS.l)
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
    assert_page_title(:OBSERVATIONS.l)
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

    assert_page_title(:OBSERVATIONS.l)
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

    assert_page_title(:OBSERVATIONS.l)
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
    assert_page_title(:OBSERVATIONS.l)
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

    assert_page_title(:OBSERVATIONS.l)
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

  def test_index_where
    location = locations(:obs_default_location)

    login
    get(:index, params: { where: location.name })
    assert_page_title(:OBSERVATIONS.l)
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
    assert_page_title(:OBSERVATIONS.l)
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
    next_href = observations_path(params: { page: 2, q: })
    prev_href = observations_path(params: { q: })
    assert_select("a.next_page_link[href='#{next_href}']")
    assert_select("a.prev_page_link[href='#{prev_href}']", count: 0)
    assert_select("form.page_input[action='#{observations_url}']")
    assert_select("input[type='hidden'][name='q[model]'][value='Observation']")
  end

  def test_index_project
    project = projects(:bolete_project)

    login
    get(:index, params: { project: project.id })

    assert_response(:success)
    assert_page_title(:OBSERVATIONS.l)
  end

  def test_index_project_without_observations
    project = projects(:empty_project)

    login
    get(:index, params: { project: project.id })

    assert_response(:success)
    assert_page_title(:OBSERVATIONS.l)
    assert_flash_text(:runtime_no_matches.l(type: :observation))
  end

  def test_index_species_list
    spl = species_lists(:unknown_species_list)

    login
    get(:index, params: { species_list: spl.id })

    assert_response(:success)
    assert_page_title(:OBSERVATIONS.l)
    assert_displayed_filters("#{:species_lists.l}: #{spl.title}")
  end

  def test_index_species_list_without_observations
    spl = species_lists(:first_species_list)

    login
    get(:index, params: { species_list: spl.id })

    assert_response(:success)
    assert_page_title(:OBSERVATIONS.l)
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
end
