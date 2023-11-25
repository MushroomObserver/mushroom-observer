# frozen_string_literal: true

require("application_system_test_case")

class HelpIdentifySystemTest < ApplicationSystemTestCase
  def test_identify_index_ui
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
    assert_selector("#modal_naming")

    ncc = names(:coprinus_comatus)

    within("#modal_naming") do
      fill_in("naming_name", with: ncc.text_name)
      browser.keyboard.type(:tab)
      sleep(1)
      assert_no_selector(".auto_complete")
      select("Promising", from: "naming_vote_value")
      click_commit
    end
    assert_no_selector("#modal_naming")
    debugger
  end
end
