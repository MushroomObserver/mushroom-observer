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
    assert_equal("off", user.content_filter[:has_images],
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
    # has_specimen filter
    # First test additional parts of Preferences
    obs = observations(:imged_unvouchered_obs)
    # Last search should contain obs (which lacks a specimen)
    results.assert_text(obs.id.to_s)

    # Prove that :has_specimen filter excludes voucherless Observations
    #   First verify UI
    click_on("Preferences", match: :first)
    #     :has_images should still be off
    obs_imged_checkbox = find_field("user[has_images]")
    refute(obs_imged_checkbox.checked?,
           "'#{:prefs_filters_obs_imged.t}' checkbox should be unchecked")
    #     :has_specimen should be off (It was never turned on).
    has_specimen_checkbox = find_field("user[has_specimen]")
    refute(has_specimen_checkbox.checked?,
           "'#{:prefs_obs_filters_has_specimen.t}' checkbox should be unchecked.")

    # Turn on :has_specimen
    page.check("user[has_specimen]")
    click_button("#{:SAVE_EDITS.t}", match: :first)
    user.reload
    assert_equal("TRUE", user.content_filter[:has_specimen])

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
    # has_images_filter
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
      # Verify radio box defaults
      assert(find("#has_images_off").checked?)
      assert(find("#has_specimen_off").checked?)
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

    ############################################################################
    # has_specimen filter
    # user who sees voucherless Observations, but hides imageless Observations
    user = users(:ignore_imageless_user)
    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    # Verify additional parts of Advanced Search form
    click_on("Advanced Search", match: :first)
    within(filters) do
      assert_text(:advanced_search_filter_has_specimen.t)
      assert(find("#has_specimen_off").checked?)
    end

    # Fill out and submit the form
    obs = observations(:vouchered_imged_obs)
    fill_in("Name", with: obs.name.text_name)
    choose("has_specimen_TRUE")
    find("#content").click_button("Search")

    # Advance Search Filters should override user content_filter so hits
    #   should == vouchered Observations of obs.name, both imaged and imageless
    expect = Observation.where(name: obs.name).where(specimen: true)
    results = page.find("div.results", match: :first)
    results.assert_text(obs.name.text_name, count: expect.size)
    # And hits should contain obs (which is imaged)
    results.assert_text(obs.id.to_s)
  end
end
