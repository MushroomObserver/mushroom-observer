require "test_helper"
require "capybara_helper"

# Test user filters
class FilterTest < IntegrationTestCase
  def test_user_content_filter
    # :has_images filter
    # Prove that :has_images filter excludes imageless Observations
    # This user filters out imageless Observations
    user = users(:ignore_imageless_user)
    obs = observations(:imageless_unvouchered_obs)
    imged_obss = Observation.where(name: obs.name).
                             where.not(thumb_image_id: nil)

    reset_session!
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
    obs_imged_checkbox = find_field("user[has_images]")
    assert(obs_imged_checkbox.checked?,
           "'#{:prefs_filters_obs_imged.t}' checkbox should be checked.")
    page.uncheck("user[has_images]")
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

    ############################################################################
    # has_specimens filter
    # First test additional parts of Preferences
    obs = observations(:imged_unvouchered_obs)
    # Last search should contain obs (which lacks a specimen)
    results.assert_text(obs.id.to_s)

    # Prove that :has_specimens filter excludes voucherless Observations
    # First verify UI
    click_on("Preferences", match: :first)
    #     :has_images should still be off
    obs_imged_checkbox = find_field("user[has_images]")
    refute(obs_imged_checkbox.checked?,
           "'#{:prefs_filters_obs_imged.t}' checkbox should be unchecked")
    #     :has_specimens should be off (It was never turned on).
    has_specimens_checkbox = find_field("user[has_specimens]")
    refute(has_specimens_checkbox.checked?,
           "'#{:prefs_obs_filters_has_specimens.t}' checkbox should be unchecked.")

    # Turn on :has_specimens
    page.check("user[has_specimens]")
    click_button("#{:SAVE_EDITS.t}", match: :first)
    user.reload
    assert_equal(true, user.content_filter[:has_specimens])

    # And repeat the search
    fill_in("search_pattern", with: obs.name.text_name)
    page.select("Observations", from: :search_type)
    click_button("Search")
    results = page.find("div.results", match: :first)
    vouchered_obss = Observation.where(name: obs.name).where(specimen: true)

    # Number of hits should == number of **vouchered** Observations of obs.name
    results.assert_text(obs.name.text_name, count: vouchered_obss.size)
    # And hits should not contain obs (which is unvouchered)
    results.assert_no_text(obs.id.to_s)
  end

  def test_advanced_search_filters
    # Login a user who filters out imageless Observations
    user = users(:ignore_imageless_user)
    obs = observations(:imageless_unvouchered_obs)
    imged_obss = Observation.where(name: obs.name).
                             where.not(thumb_image_id: nil)
    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    # Verfy Advanced Search form
    click_on("Advanced Search", match: :first)
    filters = page.find("div#advanced_search_filters")
    within("div#advanced_search_filters") do
      # Verify Labels.
      assert_text(:advanced_search_filters.t)
      assert_text(:advanced_search_filter_has_images.t)
      # Verify Filters and default values
      assert(find("#search_has_images_off").checked?)
   end

    # Fill out and submit the form
    fill_in("Name", with: obs.name.text_name)
    find("#content").click_button("Search")

    # Advance Search Filters should override user's { has_images: "NOT NULL" }
    results = page.find("div.results", match: :first)
    # Number of hits should == **total** Observations of obs.name
    results.assert_text(obs.name.text_name,
                        count: Observation.where(name: obs.name).size)
    # And hits should contain obs (which is imageless)
    results.assert_text(obs.id.to_s)
  end
end
