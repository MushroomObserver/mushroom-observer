# frozen_string_literal: true

require("application_system_test_case")

class HelpIdentifySystemTest < ApplicationSystemTestCase
  def test_identify_index_naming_and_vote_ui
    browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    within("#navigation") do
      assert_link("Help Identify")
      click_on("Help Identify")
    end
    assert_selector("body.identify__index")

    obs = observations(:wolf_fart)
    assert_link(obs.text_name)
    assert_selector("#box_#{obs.id}")

    within("#box_#{obs.id}") do
      assert_selector(".theater-btn", visible: false)
      first(".theater-btn", visible: false).trigger("click").trigger("click")
    end
    # lightgallery specific:
    assert_selector(".lg-sub-html")
    within(".lg-sub-html") do
      click_on("Propose a Name")
    end
    assert_selector("#modal_obs_#{obs.id}_naming", wait: 12)
    assert_selector("#obs_#{obs.id}_naming_form")

    ncc = names(:coprinus_comatus)

    within("#obs_#{obs.id}_naming_form") do
      fill_in("naming_name", with: ncc.text_name)
      browser.keyboard.type(:tab)
      sleep(1)
      assert_no_selector(".auto_complete")
      select("Promising", from: "naming_vote_value")
      click_commit
    end
    assert_no_selector("#modal_obs_#{obs.id}_naming", wait: 9)
    assert_no_selector("#observation_identify_#{obs.id}")

    # lightgallery specific:
    assert_selector(".lg-container")
    within(".lg-container") do
      first(".lg-close").trigger("click")
    end
    assert_no_selector(".lg-container")

    assert_selector("#box_title_#{obs.id}", text: /#{ncc.text_name}/)
  end

  def test_mark_as_reviewed_ui
    rolf = users("rolf")
    login!(rolf)

    within("#navigation") do
      assert_link(id: "nav_identify_observations_link")
      click_link(id: "nav_identify_observations_link")
    end
    assert_selector("body.identify__index")

    box_ids = find_all(".matrix-box").first(4).pluck(:id)
    first_three = box_ids.first(3)
    last_one = box_ids.fourth

    first_three.each do |box_id|
      assert_selector("##{box_id}")
      within("##{box_id}") do
        first(".caption-reviewed-link").trigger("click")
      end
    end
    page.driver.browser.refresh

    assert_selector("##{last_one}")
    first_three.each do |box_id|
      assert_no_selector("##{box_id}")
    end
  end

  # Test that marking an observation as reviewed in the lightbox syncs to the
  # matrix box, and vice versa. This tests the Turbo Stream action and the
  # lightgallery controller's caption update functionality.
  def test_mark_as_reviewed_syncs_between_lightbox_and_matrix_box
    rolf = users("rolf")
    login!(rolf)

    within("#navigation") do
      click_link(id: "nav_identify_observations_link")
    end
    assert_selector("body.identify__index")

    # Find an observation box that has an image (theater button)
    box_with_image = find(".matrix-box:has(.theater-btn)", match: :first)
    obs_id = box_with_image[:id].sub("box_", "")

    # Verify both checkboxes start unchecked
    within(box_with_image) do
      assert_no_checked_field("box_reviewed_#{obs_id}")
    end

    # Open the lightbox
    within(box_with_image) do
      first(".theater-btn", visible: false).trigger("click").trigger("click")
    end
    assert_selector(".lg-sub-html")

    # Verify the lightbox caption checkbox is also unchecked
    within(".lg-sub-html") do
      assert_no_checked_field("caption_reviewed_#{obs_id}")
    end

    # Mark as reviewed in the lightbox
    within(".lg-sub-html") do
      find(".caption-reviewed-link").click
    end

    # Verify the matrix box checkbox is now checked (synced via Turbo Stream)
    within(box_with_image) do
      assert_checked_field("box_reviewed_#{obs_id}", wait: 5)
    end

    # Unmark in the lightbox, verify it syncs to matrix box
    within(".lg-sub-html") do
      find(".caption-reviewed-link").click
    end

    within(box_with_image) do
      assert_no_checked_field("box_reviewed_#{obs_id}", wait: 5)
    end

    # Close the lightbox
    within(".lg-container") do
      first(".lg-close").trigger("click")
    end
    assert_no_selector(".lg-container")

    # Mark in the matrix box
    within(box_with_image) do
      find(".caption-reviewed-link").click
    end

    within(box_with_image) do
      assert_checked_field("box_reviewed_#{obs_id}", wait: 5)
    end

    # Open the lightbox and verify the caption checkbox synced
    within(box_with_image) do
      first(".theater-btn", visible: false).trigger("click").trigger("click")
    end
    assert_selector(".lg-sub-html")

    within(".lg-sub-html") do
      assert_checked_field("caption_reviewed_#{obs_id}", wait: 5)
    end

    # Unmark in the matrix box, verify lightbox syncs
    within(box_with_image) do
      find(".caption-reviewed-link").trigger("click")
    end

    within(".lg-sub-html") do
      assert_no_checked_field("caption_reviewed_#{obs_id}", wait: 5)
    end

    # Clean up - close lightbox
    within(".lg-container") do
      first(".lg-close").trigger("click")
    end
  end
end
