# frozen_string_literal: true

require("test_helper")

class AccountTest < CapybaraIntegrationTestCase
  def test_preferences; end

  def test_profile
    login!("mary")

    # cheating, i'm not going to use selenium just to click a dropdown
    visit("/users/#{mary[:id]}")
    click_on(text: "Edit Profile")

    assert_selector("body.profile__edit")
    within("#account_profile_form") do
      fill_in("user_name", with: "Merula Marsh")
      fill_in("user_place_name", with: locations(:mitrula_marsh).name)
      click_commit
    end
    assert_equal("Merula Marsh", mary.name)
  end

  def test_api_keys; end

  def test_edit_api_key; end

  def test_choose_password; end

  def test_signup; end
end
