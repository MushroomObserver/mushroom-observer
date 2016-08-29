require "test_helper"
require "capybara_helper"

# Test user filters
class FilterTest < IntegrationTestCase
  def test_user_image_filter
    ### Prove that :has_images filter excludes imageless Observations #####
    # This user filters out imageless Observations
    user = users(:ignore_imageless_user)
    obs = observations(:imageless_unvouchered_obs)
    imged_obss = Observation.where(name: obs.name).
                             where.not(thumb_image_id: nil)

    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    # search for Observations with same name as obs
    fill_in("search_pattern", with: obs.name.text_name)
    page.select("Observations", from: :search_type)
    click_button("Search")
    assert_match(%r{#{:app_title.l }: Observations Matching ‘#{obs.name.text_name}},
                 page.title, "Wrong page")
    results = page.find("div.results", match: :first)

    # Number of hits should == number of **imaged** Observations of obs.name
    results.assert_text(obs.name.text_name, count: imged_obss.size)
    # And hits should not contain obs (which is imageless)
    results.assert_no_text(obs.id.to_s)

    ### Now prove that turning filter off stops filtering ##################
    # Prove that preference page UI works
    click_on("Preferences", match: :first)
    assert(page.has_content?("Observation Filters"),
           "Preference page lacks Observation Filters section")
    obs_imged_checkbox = find_field("user[filter_obs_imged_checkbox]")
    assert(obs_imged_checkbox.checked?,
           "'#{:prefs_filters_obs_imged.t}' checkbox should be checked.")
    page.uncheck("user[filter_obs_imged_checkbox]")
    click_button("#{:SAVE_EDITS.t}", match: :first)
    refute(obs_imged_checkbox.checked?,
           "'#{:prefs_filters_obs_imged.t}' checkbox should be unchecked")
    user.reload
    assert_equal(nil, user.content_filter[:has_images],
                 "Unchecking and saving should turn off filter")

    # Repeat the search
    fill_in("search_pattern", with: obs.name.text_name)
    page.select("Observations", from: :search_type)
    click_button("Search")
    results = page.find("div.results", match: :first)

    # Number of hits should == **total** Observations of obs.name
    results.assert_text(obs.name.text_name,
                        count: Observation.where(name: obs.name).size)
    # And hits should contain obs (which is imageless)
    results.assert_text(obs.id.to_s)
  end
end
