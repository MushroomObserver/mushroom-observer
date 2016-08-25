require "test_helper"
require "capybara_helper"

# Test user filters
class FilterTest < IntegrationTestCase
  def test_user_filter_preferences_ui
    user = users(:zero_user)
    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    click_on("Preferences", match: :first)
    assert(page.has_content?("Observation Filters"),
           "Preference page lacks Observation Filters section")

    obs_imged_checkbox = find_field("user[filter_obs_imged]")
    refute(obs_imged_checkbox.checked?,
           "'#{:prefs_filters_obs_imged.t}' checkbox should be unchecked.")

    page.check("user[filter_obs_imged]")
    click_button("#{:SAVE_EDITS.t}", match: :first)
    user.reload
    assert_equal(true, user.filter_obs_imged)
  end

  def test_user_filter_ignore_imageless_observations
    user = users(:ignore_imageless_user)
    obs = observations(:imageless_unvouchered_obs)
    imged_obss = Observation.where(name: obs.name).
                             where.not(thumb_image_id: nil)

    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    visit(root_path)
    fill_in("search_pattern", with: obs.name.text_name)
    page.select("Observations", from: :search_type)
    click_button("Search")
    assert_match(%r{#{:app_title.l }: Observations Matching ‘#{obs.name.text_name}},
                 page.title, "Wrong page")
    results = page.find("div.results", match: :first)

    # Number of search results should == number of imaged Obss of obs.name
    results.assert_text(obs.name.text_name, count: imged_obss.size)
    # And results should not contain obs (which is imageless)
    results.assert_no_text(obs.id.to_s)
  end
end
