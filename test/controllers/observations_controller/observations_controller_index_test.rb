# frozen_string_literal: true

require("test_helper")

class ObservationsControllerIndexTest < FunctionalTestCase
  tests ObservationsController

  ######## Index ################################################
  # Tests of index, with tests arranged as follows:
  # default subaction; then
  # other subactions in order of index_active_params
  # miscellaneous tests using get(:index)

  # First, test that the index does not require login - AN 20230923
  def test_index_no_login
    # login
    get(:index)

    assert_template("shared/_matrix_box")
    assert_displayed_title("Observations by #{:sort_by_rss_log.l}")
  end

  def test_index_sorted_by_name
    by = "name"

    login
    get(:index, params: { by: by })

    assert_displayed_title("Observations by #{by.capitalize}")
  end

  def test_index_sorted_by_user
    by = "user"

    login
    get(:index, params: { by: by })

    assert_displayed_title("Observations by #{by.capitalize}")
  end

  def test_index_sorted_by_invalid_order
    by = "edibility"

    login

    exception = assert_raise(RuntimeError) do
      get(:index, params: { by: by })
    end
    assert_equal("Can't figure out how to sort Observations by :#{by}.",
                 exception.message)
  end

  def test_index_with_id
    obs = observations(:agaricus_campestris_obs)

    login
    get(:index, params: { id: obs.id })

    assert_template("shared/_matrix_box")
    # assert_displayed_title("Observation Index")
    assert_select("body.observations__index", true)
    assert_select(
      "#results .rss-heading a[href ^= '/#{obs.id}'] .rss-name",
      { text: obs.format_name.t.strip_html },
      "Index should open at the page that includes #{obs.format_name}"
    )
    assert_select("#results a", { text: "« Prev" },
                  "Wrong page or display is missing a link to Prev page")
  end

  # Created in response to a bug seen in the wild
  # place_name isn't a param for Observation#index
  # but is an API param and a param for Observation#create
  def test_index_useless_param
    params = { place_name: "Burbank" }

    login
    get(:index, params: params)

    assert_displayed_title("Observations by #{:sort_by_rss_log.l}")
  end

  def test_index_useless_param_page2
    params = { place_name: "Burbank", page: 2 }

    login
    get(:index, params: params)

    assert_displayed_title("Observations by #{:sort_by_rss_log.l}")
    assert_select("#results a", { text: "« Prev" },
                  "Wrong page or display is missing a link to Prev page")
  end

  def test_index_advanced_search_name_and_location_multiple_hits
    name = "Agaricus"
    location = "California"
    expected_hits = Observation.where(Observation[:text_name] =~ name).
                    where(Observation[:where] =~ location)

    login
    get(:index,
        params: { name: name, user_where: location, advanced_search: true })

    assert_response(:success)
    assert_select(
      "#results .rss-what a:match('href', ?)", %r{^/\d},
      { count: expected_hits.count },
      "Wrong number of results"
    )
    assert_displayed_title("Matching Observations")
  end

  def test_index_advanced_search_name_one_hit
    obs = observations(:strobilurus_diminutivus_obs)
    search_string = obs.text_name
    query = Query.lookup_and_save(:Observation, name: search_string)
    assert(query.results.one?,
           "Test needs a string that has exactly one hit")

    login
    get(:index,
        params: @controller.query_params(query).merge(advanced_search: true))

    assert_match(/#{obs.id}/, redirect_to_url,
                 "Advanced Search with 1 hit should show the hit")
  end

  def test_index_advanced_search_no_hits
    query = Query.lookup_and_save(:Observation,
                                  name: "Don't know",
                                  user: "myself",
                                  content: "Long pink stem and small pink cap",
                                  user_where: "Eastern Oklahoma")

    login
    get(:index,
        params: @controller.query_params(query).merge({ advanced_search: "1" }))

    assert_select("title", { text: "#{:app_title.l}: Index" },
                  "Wrong page or metadata <title>")
    assert_flash_text(:runtime_no_matches.l(type: :observations.l))
    assert_displayed_title("")
  end

  def test_index_advanced_search_notes1
    login
    get(:index,
        params: {
          advanced_search: true,
          name: "Fungi",
          user_where: "String in notes"
          # Deliberately omit search_location_notes: 1
        })

    assert_response(:success)
    assert_select(
      "#results a", false,
      "There should be no results when string is missing from notes, " \
      "and search_location_notes param is missing"
    )
    assert_flash_text(:runtime_no_matches.l(type: :observations.l))
    assert_displayed_title("")
  end

  def test_index_advanced_search_notes2
    login
    # Include notes, but notes don't have string yet!
    get(
      :index,
      params: {
        advanced_search: true,
        name: "Fungi",
        user_where: '"String in notes"',
        search_location_notes: 1
      }
    )

    assert_response(:success)
    assert_select(
      "#results a", false,
      "There should be no results when string is missing from notes, " \
      "even if search_location_notes param is true"
    )
    assert_flash_text(:runtime_no_matches.l(type: :observations.l))
    assert_displayed_title("")
  end

  def test_index_advanced_search_notes3
    # Add string to notes, make sure it is actually added.
    login("rolf")
    loc = locations(:burbank)
    loc.notes = "blah blah blahString in notesblah blah blah"
    loc.save
    loc.reload
    assert(loc.notes.to_s.include?("String in notes"))

    login
    # Forget to include notes again.
    get(:index,
        params: {
          advanced_search: true,
          name: "Fungi",
          user_where: "String in notes"
          # Deliberately omit search_location_notes: 1
        })

    assert_response(:success)
    assert_select(
      "#results a", false,
      "There should be no results when notes include search string, " \
      "if search_location_notes param is missing"
    )
    assert_flash_text(:runtime_no_matches.l(type: :observations.l))
    assert_displayed_title("")
  end

  def test_index_advanced_search_notes4
    # Add string to notes, make sure it is actually added.
    login("rolf")
    loc = locations(:burbank)
    loc.notes = "blah blah blahString in notesblah blah blah"
    loc.save
    loc.reload
    assert(loc.notes.to_s.include?("String in notes"))

    login
    # Now it should finally find the three unknowns at Burbank because Burbank
    # has the magic string in its notes, and we're looking for it.
    get(:index,
        params: {
          advanced_search: true,
          name: "Fungi",
          user_where: '"String in notes"',
          search_location_notes: 1
        })

    assert_response(:success)

    results = @controller.instance_variable_get(:@objects)
    assert_equal(3, results.length)
  end

  def test_index_advanced_search_error
    query_no_conditions = Query.lookup_and_save(:Observation)

    login
    params = @controller.query_params(query_no_conditions).
             merge(advanced_search: true)
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

  def test_index_pattern_multiple_hits
    pattern = "Agaricus"

    login
    get(:index, params: { pattern: pattern })

    # Because this pattern is a name, the title will reflect that Query is
    # assuming this is a search by name with synonyms and subtaxa.
    assert_displayed_title("Observations of #{pattern}")
    assert_select(
      "#results a:match('href', ?)", %r{^/\d+},
      { text: /#{pattern}/i,
        count: Observation.where(Observation[:text_name] =~ /#{pattern}/i).
               count },
      "Wrong number of results displayed"
    )
  end

  def test_index_pattern_needs_naming_with_filter
    pattern = "Briceland"

    login
    get(:index, params: { pattern: pattern, needs_naming: true })

    assert_displayed_title("")
    assert_match(/^#{identify_observations_url}/, redirect_to_url,
                 "Wrong page. Should redirect to #{:obs_needing_id.l}")
  end

  def test_index_pattern1
    pattern = "Boletus edulis"

    login
    get(:index, params: { pattern: pattern })

    # assert_displayed_title("Observations Matching ‘#{pattern}’")
    assert_displayed_title(
      :query_title_of_name.t(types: "Observations", name: pattern)
    )
    assert_not_empty(css_select('[id="right_tabs"]').text, "Tabset is empty")
  end

  def test_index_pattern_page2
    pattern = "Boletus edulis"

    login
    get(:index, params: { pattern: pattern, page: 2 })

    # assert_displayed_title("Observations Matching ‘#{pattern}’")
    assert_displayed_title(
      :query_title_of_name.t(types: "Observations", name: pattern)
    )
    assert_not_empty(css_select('[id="right_tabs"]').text, "Tabset is empty")
    assert_select("#results a", { text: "« Prev" },
                  "Wrong page or display is missing a link to Prev page")
  end

  def test_index_pattern_no_hits
    pattern = "no hits"

    login
    get(:index, params: { pattern: pattern })

    assert_empty(css_select('[id="right_tabs"]').text,
                 "RH tabset should be empty when search has no hits")
    assert_displayed_title(:title_for_observation_search.l)
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
    get(:index, params: { pattern: pattern, needs_naming: true })

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

    login
    get(:index, params: { look_alikes: "1", name: name.id })

    assert_displayed_title("Observations of #{name.text_name}")
    assert_select(
      "#results a:match('href', ?)", %r{^/\d+},
      { count: look_alikes },
      "Wrong number of results displayed"
    )
  end

  def test_index_look_alikes_no_hits
    obs = observations(:strobilurus_diminutivus_obs)
    name = obs.name
    look_alikes = Observation.joins(:namings).
                  where(namings: { name: name }).
                  where.not(name: name).count
    assert(look_alikes.zero?, "Test needs different fixture")

    login
    get(:index, params: { look_alikes: "1", name: name.id })

    assert_response(:success)
    assert_displayed_title("")
    assert_select(
      "#results a:match('href', ?)", %r{^/\d+},
      { count: look_alikes },
      "Wrong number of results displayed"
    )
  end

  def test_index_related_taxa
    name = names(:tremella_mesenterica)
    parent = name.parents.first
    obss_of_related_taxa =
      Observation.unscoped.where(
        name: Name.where(Name[:text_name] =~ /#{parent.text_name} /).or(
          Name.where(Name[:classification] =~ /: _#{parent.text_name}_/)
        ).or(Name.unscoped.where(id: parent.id))
      )

    login
    get(:index, params: { related_taxa: "1", name: name.text_name })
    assert_displayed_title("Observations of #{parent.text_name}")
    assert_select(
      "#results a:match('href', ?)", %r{^/\d+},
      { count: obss_of_related_taxa.count },
      "Wrong number of results displayed"
    )
  end

  def test_index_name
    name = names(:fungi)
    ids = Observation.where(name: name).map(&:id)
    assert(ids.length.positive?, "Test needs different fixture for 'name'")
    params = { name: name }

    login("zero") # Has no observations
    get(:index, params: params)

    assert_response(:success)
    assert_displayed_title("Observations of #{name.text_name}")
    ids.each do |id|
      assert_select(
        "a:match('href', ?)", %r{^/#{id}}, true,
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

    assert_displayed_title("Observations created by #{user.name}")
    assert_select(
      "#results img.image_#{obs.thumb_image_id}",
      true,
      "Observation thumbnail should display although this is not an rss_log"
    )
    assert_select(
      "#results a:match('href', ?)", %r{^/\d+},
      { text: /\S+/, # ignore links in buttons
        count: Observation.where(user: user).count },
      "Wrong number of results displayed"
    )
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

    assert_displayed_title("Matching Observations")
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
    assert_displayed_title("")
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

  def test_index_where
    location = locations(:obs_default_location)

    login
    get(:index, params: { where: location.name })
    assert_displayed_title("Observations from #{location.name}")
    assert_match(new_location_path(where: location.name), @response.body)
  end

  def test_index_where_page2
    location = locations(:obs_default_location)

    login
    get(:index, params: { where: location.name, page: 2 })
    assert_select("#results a", { text: "« Prev" },
                  "Wrong page or display is missing a link to Prev page")
    assert_displayed_title("Observations from #{location.name}")
    assert_not_empty(css_select('[id="right_tabs"]').text, "Tabset is empty")
  end

  def test_index_project
    project = projects(:bolete_project)

    login
    get(:index, params: { project: project.id })

    assert_response(:success)
    assert_displayed_title(project.title)
  end

  def test_index_project_without_observations
    project = projects(:empty_project)

    login
    get(:index, params: { project: project.id })

    assert_response(:success)
    assert_displayed_title(project.title)
    assert_flash_text(:runtime_no_matches.l(type: :observation))
  end

  def test_index_species_list
    spl = species_lists(:unknown_species_list)

    login
    get(:index, params: { species_list: spl.id })

    assert_response(:success)
    assert_displayed_title("Observations in #{spl.title}")
  end

  def test_index_species_list_without_observations
    spl = species_lists(:first_species_list)

    login
    get(:index, params: { species_list: spl.id })

    assert_response(:success)
    assert_displayed_title("")
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
    observations_in_region = Observation.unscoped.in_region("California, USA")

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
