# frozen_string_literal: true

require("test_helper")

class AccountTest < CapybaraIntegrationTestCase
  def test_preferences; end

  def test_profile
    mary = users("mary")
    login!(mary)

    # cheating: going direct instead of using selenium just to click a dropdown
    visit(user_path(mary))
    click_link(text: "Edit Profile")

    assert_selector("body.profile__edit")
    within("#account_profile_form") do
      fill_in("user_name", with: "Merula Marshwell")
      fill_in("user_place_name", with: locations(:mitrula_marsh).name)
      click_commit
    end

    mary.reload
    assert_flash_text(/Successfully updated profile/i)
    assert_equal("Merula Marshwell", mary.name)
    assert_equal(locations(:mitrula_marsh), mary.location)
  end

  def test_api_keys; end

  def test_edit_api_key; end

  def test_choose_password; end

  def test_signup; end
end
