# frozen_string_literal: true

require("test_helper")

# Test user filters
class QueryFiltersIntegrationTest < CapybaraIntegrationTestCase
  # Test deserialization of non-ascii characters
  # Observation and Show Location title include
  #               `             and ’
  # as            &#8216        and &#8217;
  # serialized as %26%238216%3B and %26%238217%3B
  # They are deserialized and displayed as pat of Map Locations title.
  def test_deserialize
    obs = observations(:boletus_edulis_obs)

    login
    fill_in("search_pattern", with: obs.name.text_name)
    page.select("Observations", from: :search_type)
    click_button("Search")
    click_link("Show Locations")
    click_link("Map Locations")

    title = page.find("#title")
    title.assert_text("‘#{obs.name.text_name}’")
  end

  def test_user_content_filter
    ### :has_images filter
    ### Prove that :has_images filter excludes imageless Observations
    # This user filters out imageless Observations
    user = users(:ignore_imageless_user)
    obs = observations(:imageless_unvouchered_obs)
    imged_obss = Observation.where(name: obs.name).
                 where.not(thumb_image_id: nil)

    reset_session!
    login(user)

    # search for Observations with same name as obs
    fill_in("search_pattern", with: obs.name.text_name)
    page.select("Observations", from: :search_type)
    click_button("Search")

    assert_match(
      /#{:app_title.l}: Observations Matching ‘#{obs.name.text_name}/,
      page.title, "Wrong page"
    )
    page.find("#title_bar").assert_text(:filtered.t)
    results = page.find("#results")
    # Number of hits should == number of **imaged** Observations of obs.name
    results.assert_text(obs.name.text_name, count: imged_obss.size)
    # And hits should not contain obs (which is imageless)
    results.assert_no_text(obs.id.to_s)

    # Show Locations (from obs index) should be filtered
    click_link("Show Locations")
    page.find("#title_bar").assert_text(:filtered.t)

    # And mapping them (from locations index) should also be filtered.
    click_link("Map Locations")
    page.find("#title_bar").assert_text(:filtered.t)

    ### Now prove that turning filter off stops filtering ###
    # Prove that preference page UI works
    click_on("Preferences", match: :first)
    assert(page.has_content?(:prefs_content_filters.t),
           "Preference page lacks Content Filters section")
    obs_imged_checkbox = find_field("user[has_images]")
    assert(obs_imged_checkbox.checked?,
           "'#{:prefs_filters_has_images.t}' checkbox should be checked.")
    page.uncheck("user[has_images]")
    click_button(:SAVE_EDITS.t.to_s, match: :first)

    obs_imged_checkbox = find_field("user[has_images]")
    assert_not(obs_imged_checkbox.checked?,
               "'#{:prefs_filters_has_images.t}' checkbox should be unchecked")
    user.reload
    assert_nil(user.content_filter[:has_images],
               "Unchecking and saving should turn off filter")
    assert_nil(user.content_filter[:has_specimen],
               "Has specimen filter should be off")
    assert_blank(user.content_filter[:region],
                 "Region filter should be off")

    # Repeat the search
    fill_in("search_pattern", with: obs.name.text_name)
    page.select("Observations", from: :search_type)
    click_button("Search")

    page.find("#title_bar").assert_no_text(:filtered.t)

    results = page.find("#results")
    # Number of hits should == **total** Observations of obs.name
    results.assert_text(obs.name.text_name,
                        count: Observation.where(name: obs.name).size)
    # And hits should contain obs (which is imageless)
    results.assert_text(obs.id.to_s)

    ############################################################################
    # has_specimen filter

    # We just did a completely unfiltered search
    # With :has_specimen off, search results should include unvouchered obs
    obs = observations(:imged_unvouchered_obs)
    results.assert_text(obs.id.to_s)

    # Verify Prefences UI
    click_on("Preferences", match: :first)
    #   :has_images should still be off
    obs_imged_checkbox = find_field("user[has_images]")
    assert_not(obs_imged_checkbox.checked?,
               "'#{:prefs_filters_has_images.t}' checkbox should be unchecked")
    #   :has_specimen should be off (It was never turned on).
    has_specimen_checkbox = find_field("user[has_specimen]")
    assert_not(
      has_specimen_checkbox.checked?,
      "'#{:prefs_filters_has_specimen.t}' checkbox should be unchecked."
    )

    #   Turn on :has_specimen
    page.check("user[has_specimen]")
    click_button(:SAVE_EDITS.t.to_s, match: :first)
    user.reload
    assert_equal("yes", user.content_filter[:has_specimen])

    # Prove that :has_specimen filter excludes voucherless Observations
    # Repeat the search
    fill_in("search_pattern", with: obs.name.text_name)
    page.select("Observations", from: :search_type)

    click_button("Search")
    page.find("#title_bar").assert_text(:filtered.t)

    results = page.find("#results")
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
    login(user)

    # Verfy Advanced Search form
    click_on("Advanced Search", match: :first)
    within("#advanced_search_filters") do
      # Verify Labels.
      assert_text(:advanced_search_filters.t)
      assert_text(:advanced_search_filter_has_images.t)
      # Verify radio box defaults
      assert(find("#content_filter_has_images_yes").checked?)
      assert(find("#content_filter_has_specimen_").checked?)
    end

    # Fill out and submit the form
    # (override their default preference to ignore imageless obs)
    fill_in("Name", with: obs.name.text_name)
    page.choose("content_filter_has_images_")
    first(:button, :advanced_search_submit.l).click

    # Advance Search Filters should override user's { has_images: "yes" }
    page.find("#title_bar").assert_no_text(:filtered.t)

    results = page.find("#results")
    # Number of hits should == **total** Observations of obs.name
    results.assert_text(obs.name.text_name,
                        count: Observation.where(name: obs.name).size)
    # And hits should contain obs (which is imageless)
    results.assert_text(obs.id.to_s)

    ############################################################################
    # has_specimen filter
    # user who sees voucherless Observations, but hides imageless Observations

    # Verify additional parts of Advanced Search form
    click_on("Advanced Search", match: :first)
    filters = page.find("#advanced_search_filters")
    within(filters) do
      assert(find("#content_filter_has_images_yes").checked?)
      assert(find("#content_filter_has_specimen_").checked?)
    end

    # Fill out and submit the form
    obs = observations(:vouchered_imged_obs)
    fill_in("Name", with: obs.name.text_name)
    choose("content_filter_has_images_")
    choose("content_filter_has_specimen_yes")
    first(:button, :advanced_search_submit.l).click

    # Advance Search Filters should override user content_filter so hits
    #   should == vouchered Observations of obs.name, both imaged and imageless
    page.find("#title_bar").assert_no_text(:filtered.t)
    expect = Observation.where(name: obs.name).where(specimen: true)
    results = page.find("#results")
    results.assert_text(obs.name.text_name, count: expect.size)
    # And hits should contain obs (which is imaged)
    results.assert_text(obs.id.to_s)
  end
end
