# frozen_string_literal: true

require("test_helper")

# Test typical sessions of user who never creates an account or contributes.
class LurkerTest < IntegrationTestCase
  def test_poke_around
    login
    # Start at index.
    get("/")
    assert_template("rss_logs/index")

    # Click on first observation.
    click_mo_link(href: %r{^/\d+\?}, in: :results)
    assert_template("observer/show_observation")

    # Click on prev/next
    click_mo_link(label: "Next »", in: :title)
    click_mo_link(label: "« Prev", in: :title)

    # Click on the first image.
    click_mo_link(label: :image, href: /show_image/)

    # Go back to observation and click on "About...".
    click_mo_link(label: "Show Observation")
    click_mo_link(href: /show_name/)
    assert_template("name/show_name")

    # Take a look at the occurrence map.
    click_mo_link(label: "Occurrence Map")
    assert_template("name/map")

    # Check out a few links from left-hand panel.
    click_mo_link(label: "How To Use", in: :left_panel)
    click_mo_link(label: "Français", in: :left_panel)
    click_mo_link(label: "Contributeurs", in: :left_panel)
    click_mo_link(label: "English",       in: :left_panel)
    click_mo_link(label: "Projects",      in: :left_panel)
    click_mo_link(label: "Comments",      in: :left_panel)
    click_mo_link(label: "Site Stats", in: :left_panel)
  end

  def test_show_observation
    # Use detailed_unknown_obs since it has everything.
    obs = observations(:detailed_unknown_obs).id.to_s

    login("mary")
    get("/#{obs}")
    # (make sure we're displaying original names of images)
    assert_match(/DSCN8835.JPG/u, response.body)

    # Check out the RSS log.
    save_path = path
    click_mo_link(label: "Show Log")
    click_mo_link(label: "Show Observation")
    assert_equal(save_path, path,
                 "Went to RSS log and returned, expected to be the same.")

    # Mary has done several things to it (observation itself, naming, comment).
    assert_select("a[href^='/users/#{mary.id}']", minimum: 3)
    click_mo_link(label: "Mary Newbie")
    assert_template("users/show")

    # Check out location.
    get("/#{obs}")
    # Don't include USA due to <span>
    click_mo_link(label: "Burbank, California")
    assert_template("location/show_location")

    # Check out species list.
    get("/#{obs}")
    click_mo_link(label: "List of mysteries")
    assert_template("species_list/show_species_list")
    # (Make sure detailed_unknown_obs is shown somewhere.)
    assert_select("a[href^='/#{obs}?']")

    # Click on name.
    get("/#{obs}")
    # (Should be at least two links to show the name Fungi.)
    assert_select("a[href^='/name/show_name/#{names(:fungi).id}']", minimum: 2)
    click_mo_link(label: /About.*Fungi/)
    # (Make sure the page contains create_name_description.)
    assert_select(
      "a[href^='/name/create_name_description/#{names(:fungi).id}']"
    )

    # And lastly there are some images.
    get("/#{obs}")
    assert_select("a[href^='/image/show_image']", minimum: 2)
    click_mo_link(label: :image, href: /show_image/)
    # (Make sure detailed_unknown_obs is shown somewhere.)
    assert_select("a[href^='/#{obs}']")
  end

  def test_search
    login
    get("/")

    # Search for a name.  (Only one.)
    form = open_form("form[action*=search]")
    form.change("pattern", "Coprinus comatus")
    form.select("type", "Names")
    form.submit("Search")
    assert_match(%r{^/name/show_name/#{names(:coprinus_comatus).id}},
                 @request.fullpath)

    # Search for observations of that name.  (Only one.)
    form.select("type", "Observations")
    form.submit("Search")
    assert_match(%r{^/#{observations(:coprinus_comatus_obs).id}\?},
                 @request.fullpath)

    # Image pattern searches temporarily disabled for performamce
    # 2021-09-12 JDC
    # Search for images of the same thing.  (Still only one.)
    # form.select("type", "Images")
    # form.submit("Search")
    # assert_match(
    #   %r{^/image/show_image/#{images(:connected_coprinus_comatus_image).id}},
    #   @request.fullpath
    # )

    # There should be no locations of that name, though.
    form.select("type", "Locations")
    form.submit("Search")
    assert_template("location/list_locations")
    assert_flash_text(/no.*found/i)
    assert_select("div.results a[href]", false)

    # This should give us just about all the locations.
    form.change("pattern", "california OR canada")
    form.select("type", "Locations")
    form.submit("Search")
    assert_select("div.results a[href]") do |links|
      labels = links.map { |l| l.to_s.html_to_ascii }
      assert(labels.any? { |l| l.end_with?("Canada") },
             "Expected one of the results to be in Canada.\n" \
             "Found these: #{labels.inspect}")
      assert(labels.any? { |l| l.end_with?("USA") },
             "Expected one of the results to be in the US.\n" \
             "Found these: #{labels.inspect}")
    end
  end

  def test_search_next
    login
    get("/")

    # Search for a name.  (More than one.)
    form = open_form("form[action*=search]")
    form.change("pattern", "Fungi")
    form.select("type", "Observations")
    form.submit("Search")
    obs = observations(:detailed_unknown_obs).id.to_s
    assert_select("a[href^='/#{obs}']") do |links|
      assert(links.all? { |l| l.to_s.match(/#{obs}\?q=/) })
    end
  end

  def test_obs_at_location
    login
    # Start at distribution map for Fungi.
    get("/name/map/#{names(:fungi).id}")

    # Get a list of locations shown on map. (One defined, one undefined.)
    click_mo_link(label: "Show Locations", in: :right_tabs)
    assert_template("location/list_locations")

    # Click on the defined location.

    click_mo_link(label: /Burbank/)
    assert_template("location/show_location")

    # Get a list of observations from there.  (Several so goes to index.)
    click_mo_link(label: "Observations at this Location", in: :right_tabs)
    assert_template("observer/list_observations")
    save_results = get_links("div.results a:match('href',?)", %r{^/\d+})

    observations = @controller.instance_variable_get(:@objects)
    if observations.size > MO.default_layout_count
      skip("Test skipped because it bombs when search results > " \
           "default layout size.
           Please adjust the fixtures and re-run.")
    end

    # Try sorting differently.
    click_mo_link(label: "User", in: :sort_tabs)
    results = get_links("div.results a:match('href',?)", %r{^/\d+})
    assert_equal(save_results.length, results.length)

    click_mo_link(label: "Date", in: :sort_tabs)
    results = get_links("div.results a:match('href',?)", %r{^/\d+})
    assert_equal(save_results.length, results.length)

    click_mo_link(label: "Reverse Order", in: :sort_tabs)
    results = get_links("div.results a:match('href',?)", %r{^/\d+})
    assert_equal(save_results.length, results.length)

    click_mo_link(label: "Name", in: :sort_tabs)
    results = get_links("div.results a:match('href',?)", %r{^/\d+})
    assert_equal(save_results.length, results.length)

    save_results = results
    query_params = parse_query_params(save_results.first.value)

    # Go to first observation, and try stepping back and forth.
    click_mo_link(href: %r{^/\d+\?}, in: :results)
    save_path = @request.fullpath
    assert_equal(query_params, parse_query_params(save_path))
    click_mo_link(label: "« Prev", in: :title)
    assert_flash_text(/there are no more observations/i)
    assert_equal(save_path, @request.fullpath)
    assert_equal(query_params, parse_query_params(save_path))
    click_mo_link(label: "Next »", in: :title)
    assert_no_flash
    assert_equal(query_params, parse_query_params(save_path))
    save_path = @request.fullpath
    click_mo_link(label: "Next »", in: :title)
    assert_no_flash
    assert_equal(query_params, parse_query_params(save_path))
    click_mo_link(label: "« Prev", in: :title)
    assert_no_flash
    assert_equal(query_params, parse_query_params(save_path))
    assert_equal(save_path, @request.fullpath,
                 "Went next then prev, should be back where we started.")
    click_mo_link(label: "Index", href: /index/, in: :title)
    results = get_links("div.results a:match('href',?)", %r{^/\d+})
    assert_equal(query_params, parse_query_params(results.first.value))
    assert_equal(save_results.map(&:value),
                 results.map(&:value),
                 "Went to show_obs, screwed around, then back to index. " \
                 "But the results were not the same when we returned.")
  end
end
