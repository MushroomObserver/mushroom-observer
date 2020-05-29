require "test_helper"
require "capybara_helper"

# Test typical sessions of user who never creates an account or contributes.
class CapybarLurkerTest < IntegrationTestCase
  # temporarily use these extensions until webdriver is installed
  # include here to avoid name conflict with MO extensions
  include CapybaraHelper

  def test_poke_around
    # Start at index.
    visit(root_path)

    # Test page content rather than template because:
    #   assert_template unavailable to Capybara
    #   assert_template will be deprecated in Rails 5 (but available as a gem)
    #     because (per DHH) testing content is a better practice
    # Following gives more informative error message than
    # assert(page.has_title?("#{:app_title.l}: Activity Log"), "Wrong page")
    assert_equal("#{:app_title.l}: Activity Log", page.title, "Wrong page")

    # Click on first observation in feed results
    first(:xpath, rss_observation_created_xpath).click
    assert_match(/#{:app_title.l}: Observation/, page.title, "Wrong page")

    # Click on next (catches a bug seen in the wild).
    # Above comment about "next" does not match "Prev" in code
    # push_page is a stop-gap until a js-enabled driver is installed and working
    go_back_after do
      click_link("« Prev")
    end # back at Observation
    assert_match(/#{:app_title.l}: Observation/, page.title, "Wrong page")

    # Click on the first image.
    go_back_after do
      first(:xpath, observation_image_xpath).click
      assert_match(/#{:app_title.l}: Image/, page.title, "Wrong page")
    end # back at Observation
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
    assert_equal("#{:app_title.l}: Projects by Title", page.title, "Wrong page")

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
    visit(root_path)
    first(:link, "Login").click
    assert_equal("#{:app_title.l}: Please login", page.title, "Wrong page")
    fill_in("User name or Email address:", with: lurker.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")
    assert_equal("#{:app_title.l}: Activity Log", page.title, "Login failed")

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
      # (plus a link to it is also in table of names for mobile)
      assert(
        assert_selector("#content a[href^='/users/show_user/#{owner.id}']",
                        minimum: 4)
      )

      first(:link, owner.name).click
      assert_match(/Contribution Summary/, page.title, "Wrong page")
    end # back at Observation

    # Check out location.
    go_back_after do
      click_link(obs.location.name)
      assert_match(/^#{:app_title.l}: Location/, page.title, "Login failed")
    end # back at Observation

    # Check out species list.
    go_back_after do
      list = SpeciesList.joins(:observations).
             where("observation_id = ?", obs.id).first
      click_link(list.title)
      assert_match(/^#{:app_title.l}: Species List: #{list.title}/,
                   page.title, "Wrong page")

      # (Make sure observation is shown somewhere.)
      assert(has_selector?("a[href^='/#{obs.id}']"),
             "Missing a link to Observation")
    end # back at Observation

    # Check out Name
    go_back_after do
      # (Should be at least two links to show the Name.)
      assert(assert_selector("#content a[href^='/names/show_name/#{name.id}']",
                             minimum: 2))

      click_link("About #{name.text_name}")
      # (Make sure the page contains create_name_description.)
      assert(
        assert_selector(
          "#content a[href^='/names/create_name_description/#{name.id}']"
        )
      )
    end # back at Observation

    # Check out images
    # Observation has at least 2 images
    image_count = all(:xpath, observation_image_xpath).count
    assert(image_count == 2,
           "expected 2 Images in Observation, got #{image_count}")
  end
end
