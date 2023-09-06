# frozen_string_literal: true

require("test_helper")

# Test typical sessions of user who never creates an account or contributes.
class LurkerTest < CapybaraIntegrationTestCase
  def test_poke_around
    # Start at index.
    reset_session!
    login

    visit("/activity_logs")
    rss_log = RssLog.where.not(observation_id: nil).order(:updated_at).last
    assert_selector("#box_#{rss_log.id} .rss-id",
                    text: rss_log.observation_id)

    # Click on first obs immediately after one that has images.
    # NOTE: BS3 matrix-box are a bit harder to find siblings
    # because the layout clearfix boxes interrupt the matrix boxes.
    # This selects next matching peer, but you can do adjacent in bs4
    # (do + instead of ~)
    first(".image-link").ancestor(".matrix-box~.matrix-box").
      first(".rss-detail", text: "Observation Created").
      ancestor(".panel").first(".rss-box-details").first("a").click
    assert_match(/#{:app_title.l}: Observation/, page.title, "Wrong page")

    # Click on next (catches a bug seen in the wild).
    # Above comment about "next" does not match "Prev" in code
    go_back_after do
      click_link("« Prev")
    end
    # back at Observation
    assert_match(/#{:app_title.l}: Observation/, page.title, "Wrong page")

    # Click on the first image. (That's why we picked the one after this.)
    go_back_after do
      first("#observation_carousel .image-link").click
      assert_match(/#{:app_title.l}: Image/, page.title, "Wrong page")
    end
    # back at Observation
    assert_match(/#{:app_title.l}: Observation/, page.title, "Wrong page")

    # Go back to observation and click on "About...".
    click_link("About ")
    assert_match(/#{:app_title.l}: Name/, page.title, "Wrong page")

    # Take a look at the occurrence map.
    click_link("Occurrence Map")
    assert_match(/#{:app_title.l}: Occurrence Map/, page.title, "Wrong page")

    # Check out a few links from left-hand panel.
    click_on("How To Use")
    assert_match(/#{:app_title.l}: How to Use/, page.title, "Wrong page")

    click_on("Français")
    subtitle = if :how_title.has_translation?
                 :how_title.t
               else
                 "How to Use"
               end
    assert_match(/#{:app_title.l}: #{subtitle}/, page.title, "Wrong page")

    click_on("Contributeurs")
    subtitle = if :users_by_contribution_title.has_translation?
                 :users_by_contribution_title.t
               else
                 "List of Contributors"
               end
    assert_equal("#{:app_title.l}: #{subtitle}", page.title, "Wrong page")

    click_on("English")
    assert_equal("#{:app_title.l}: List of Contributors",
                 page.title, "Wrong page")

    click_on("Projects")
    assert_equal("#{:app_title.l}: Projects by Time Last Modified", page.title,
                 "Wrong page")

    click_on("Comments")
    assert_equal("#{:app_title.l}: Comments by Date Created",
                 page.title, "Wrong page")

    click_on("Site Stats")
    assert_equal("#{:app_title.l}: Site Statistics", page.title, "Wrong page")
  end

  def test_show_observation
    reset_session!
    # Use detailed_unknown since it has everything.
    lurker = users(:katrina)
    obs = observations(:detailed_unknown_obs)
    owner = obs.user
    name = obs.name

    # First login
    reset_session!
    login(lurker.login)

    visit("/#{obs.id}")
    assert_match(/#{:app_title.l}: Observation #{obs.id}/, page.title,
                 "Wrong page")

    # Make sure we're displaying original names of images
    assert(page.has_content?(obs.images.first.original_name),
           "Original filename of image not displayed")

    save_path = current_path
    click_link("Show Log")
    click_link("Show Observation")
    assert_equal(save_path, current_path,
                 "Went to RSS log and returned, expected path to be the same.")

    # Check out User links and profile
    go_back_after do
      # Owner has done several things to Observation:
      #  Observation itself, naming, comment.
      assert(
        assert_selector("#content a[href^='/users/#{owner.id}']",
                        minimum: 3)
      )

      first(:link, owner.name).click
      assert_match(/Contribution Summary/, page.title, "Wrong page")
    end
    # back at Observation

    # Check out location.
    go_back_after do
      click_link(obs.location.name)
      assert_match(/^#{:app_title.l}: Location/, page.title, "Login failed")
    end
    # back at Observation

    # Check out species list.
    go_back_after do
      list = SpeciesList.joins(:observations).
             where(observations: { id: obs.id }).first
      click_link(list.title)
      assert_match(/^#{:app_title.l}: Species List: #{list.title}/,
                   page.title, "Wrong page")

      # (Make sure observation is shown somewhere.)
      assert(has_selector?("a[href^='#{observation_path(obs.id)}']"),
             "Missing a link to Observation")
    end
    # back at Observation

    # Check out Name
    go_back_after do
      # (Should be at least two links to show the Name.)
      assert(assert_selector("#content a[href^='/names/#{name.id}']",
                             minimum: 2))

      click_link("About #{name.text_name}")
      # (Make sure the page contains create_name_description.)
      assert(
        assert_selector(
          "#content a[href^='/names/#{name.id}/descriptions/new']"
        )
      )
    end
    # back at Observation

    # Check out images
    # Observation has at least 2 images
    image_count = all("#content .carousel img.carousel-thumbnail").count
    assert(image_count == 2,
           "expected 2 Images in Observation, got #{image_count}")
  end

  def test_search
    login

    # Search for a name.  (Only one.)
    fill_in("search_pattern", with: "Coprinus comatus")
    select("Names", from: "search_type")
    click_button("Search")
    assert_match(names(:coprinus_comatus).search_name,
                 page.title, "Wrong page")

    # Search for observations of that name.  (Only one.)
    select("Observations", from: "search_type")
    click_button("Search")
    assert_match(/#{observations(:coprinus_comatus_obs).id}/,
                 page.title, "Wrong page")

    # Image pattern searches temporarily disabled for performamce
    # 2021-09-12 JDC
    # Search for images of the same thing.  (Still only one.)
    # select("Images", from: "search_type")
    # click_button("Search")
    # assert_match(
    #   %r{^/image/show_image/#{images(:connected_coprinus_comatus_image).id}},
    #   current_fullpath
    # )

    # There should be no locations of that name, though.
    select("Locations", from: "search_type")
    click_button("Search")
    assert_match("Index", page.title, "Wrong page")
    assert_selector("div.alert", text: /no.*found/i)
    refute_selector("#results a[href]")

    # This should give us just about all the locations.
    fill_in("search_pattern", with: "california OR canada")
    select("Locations", from: "search_type")
    click_button("Search")
    # assert_selector("#results a[href]")
    labels = find_all("#results a[href]").map(&:text)
    assert(labels.any? { |l| l.end_with?("Canada") },
           "Expected one of the results to be in Canada.\n" \
           "Found these: #{labels.inspect}")
    assert(labels.any? { |l| l.end_with?("USA") },
           "Expected one of the results to be in the US.\n" \
           "Found these: #{labels.inspect}")
  end

  def test_search_from_obs_needing_ids
    login

    visit("/observations/identify")
    # Search for a location.
    place = "Massachusetts, USA"
    fill_in("filter_term", with: place)
    select("Region", from: "filter_type")
    click_button("Search")
    assert_match(/#{:obs_needing_id.t}/, page.title, "Wrong page")
    where_ats = find_all(".rss-where").map(&:text)
    assert(where_ats.all? { |wa| wa.match(place) },
           "Expected only obs from #{place}" \
           "Found these: #{where_ats.inspect}")
  end

  def test_search_next
    login

    # Search for a name.  (More than one.)
    fill_in("search_pattern", with: "Fungi")
    select("Observations", from: "search_type")
    click_button("Search")

    obs = observations(:detailed_unknown_obs).id.to_s
    # assert_selector("a[href^='/#{obs}']")
    links = find_all("a[href^='/#{obs}']")
    assert(links.all? { |l| l[:href].match(/#{obs}\?q=/) },
           "Expected a link to reference #{obs}?q=??.\n" \
           "Found these: #{links.inspect}")
  end

  def test_obs_at_location
    login
    # Start at distribution map for Fungi.
    visit("/names/#{names(:fungi).id}/map")

    # Get a list of locations shown on map. (One defined, one undefined.)
    within("#right_tabs") { click_link("Show Locations") }
    assert_match("Locations with Observations", page.title, "Wrong page")

    # Click on the defined location.
    click_link(text: /Burbank/)
    assert_match("Location: Burbank, California, USA", page.title, "Wrong page")

    # Get a list of observations from there.  (Several so goes to index.)
    within("#right_tabs") { click_link(text: "Observations at this Location") }
    assert_match("Observations from Burbank",
                 page.title, "Wrong page")
    save_results = find_all("#results a").select do |l|
      l[:href].match(%r{^/\d+})
    end

    # Bail if there are too many results — test will not work
    if has_selector?("#results .pagination a", text: /Next/)
      skip("Test skipped because it bombs when search results > " \
          "default layout size.
          Please adjust the fixtures and re-run.")
    end

    # Try sorting differently.
    within("#sorts") { click_link(text: "User") }
    check_results_length(save_results)

    # Date is ambiguous, there's also 'Date Posted'
    within("#sorts") { click_link(exact_text: "Date") }
    check_results_length(save_results)

    within("#sorts") { click_link(text: "Reverse Order") }
    check_results_length(save_results)

    within("#sorts") { click_link(text: "Name") }
    # Last time through - reset `save_results` with current results
    save_results = check_results_length(save_results)
    # Must set `save_hrefs` here to avoid variable going stale...
    # Capybara::RackTest::Errors::StaleElementReferenceError
    save_hrefs = save_results.pluck(:href)

    query_params = parse_query_params(save_results.first[:href])

    # Go to first observation, and try stepping back and forth.
    results_observation_links.first.click
    save_path = current_fullpath
    assert_equal(query_params, parse_query_params(save_path))
    within("#title_bar") { click_link(text: "Prev") }
    assert_flash_text(/there are no more observations/i)
    assert_equal(save_path, current_fullpath)
    assert_equal(query_params, parse_query_params(save_path))
    within("#title_bar") { click_link(text: "Next") }
    assert_no_flash
    assert_equal(query_params, parse_query_params(save_path))

    save_path = current_fullpath
    within("#title_bar") { click_link(text: "Next") }
    assert_no_flash
    assert_equal(query_params, parse_query_params(save_path))
    within("#title_bar") { click_link(text: "Prev") }
    assert_no_flash
    assert_equal(query_params, parse_query_params(save_path))
    assert_equal(save_path, current_fullpath,
                 "Went next then prev, should be back where we started.")
    within("#title_bar") do
      click_link(text: "Index") # href: /#{observations_path}/
    end
    results = results_observation_links
    assert_equal(query_params, parse_query_params(results.first[:href]))
    assert_equal(save_hrefs, results.pluck(:href),
                 "Went to show_obs, screwed around, then back to index. " \
                 "But the results were not the same when we returned.")
  end

  ################

  private

  # Custom login method for this test. Consider adding the bells and whistles
  # to the method in CapybaraSessionExtensions?
  def login(login = users(:zero_user).login)
    visit(root_path)
    first(:link, "Login").click
    assert_equal("#{:app_title.l}: Please login", page.title, "Wrong page")
    fill_in("user_login", with: login)
    fill_in("user_password", with: "testpassword")
    click_button("Login")

    # Following gives more informative error message than
    # assert(page.has_title?("#{:app_title.l }: Activity Log"), "Wrong page")
    assert_equal(
      "#{:app_title.l}: Observations by #{:sort_by_rss_log.l}",
      page.title, "Login failed"
    )
  end

  # This returns results so you can reset a `results` variable within test scope
  def check_results_length(save_results)
    results = results_observation_links
    assert_equal(save_results.length, results.length)
    results
  end

  def results_observation_links
    find_all("#results a").select do |l|
      l[:href].match(%r{^/\d+})
    end
  end
end
