require "test_helper"
require "capybara_helper"

# Test typical sessions of user who never creates an account or contributes.
class FilterTest < IntegrationTestCase
  # temporarily use these extensions until webdriver is installed
  # include here to avoid name conflict with MO extensions
  include CapybaraHelper

  def test_user_preferences
    user = users(:mary)

    visit("account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    click_on("Preferences", match: :first)
  end

  def test_show_observation
    skip  # This method here temporarily only as an example

    # Use detailed_unknown since it has everything.
    lurker = users(:katrina)
    obs = observations(:detailed_unknown_obs)
    owner = obs.user
    name = obs.name

    # First login
    visit(root_path)
    first(:link, "Login").click
    assert_equal("#{:app_title.l }: Please login", page.title, "Wrong page")
    fill_in("User name or Email address:", with: lurker.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")
    assert_equal("#{:app_title.l }: Activity Log", page.title, "Login failed")

    visit("/#{obs.id}")
    assert_match(%r{#{:app_title.l }: Observation #{obs.id}}, page.title,
                 "Wrong page")

    # Make sure we're displaying original names of images
    img = Image.where(observation = obs.id).first
    assert(page.has_content?(img.original_name),
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
        assert_selector("#content a[href^='/observer/show_user/#{owner.id}']",
                        minimum: 4))

      first(:link, owner.name).click
      assert_match(%r{Contribution Summary}, page.title, "Wrong page")
    end # back at Observation

    # Check out location.
    go_back_after do
      click_link(obs.location.name)
      assert_match(%r{^#{:app_title.l }: Location}, page.title, "Login failed")
    end # back at Observation

    # Check out species list.
    go_back_after do
      list = SpeciesList.joins(:observations).
                         where("observation_id = ?", obs.id).first
      click_link(list.title)
      assert_match(%r{^#{:app_title.l }: Species List: #{list.title}},
                   page.title, "Wrong page")

      # (Make sure observation is shown somewhere.)
      assert(has_selector?("a[href^='/#{obs.id}']"),
                           "Missing a link to Observation")
    end # back at Observation

    # Check out Name
    go_back_after do
      # (Should be at least two links to show the Name.)
      assert(assert_selector("#content a[href^='/name/show_name/#{name.id}']",
                             minimum: 2))

      click_link("About #{name.text_name}")
      # (Make sure the page contains create_name_description.)
      assert(assert_selector(
              "#content a[href^='/name/create_name_description/#{name.id}']"))
    end # back at Observation

    # Check out images
    # Observation has at least 2 images
    image_count = all(:xpath, observation_image_xpath).count
    assert(image_count == 2,
          "expected 2 Images in Observation, got #{image_count}")
  end
end
