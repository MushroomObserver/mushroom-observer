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

    # Don't forget to reload the record after updating!
    mary.reload
    assert_flash_text(/Successfully updated profile/i)
    assert_equal("Merula Marshwell", mary.name)
    assert_equal(locations(:mitrula_marsh), mary.location)
  end

  def test_api_keys
    mary = users("mary")
    # Mary has one existing api key, "marys_api_key"
    marys_api_key = api_keys("marys_api_key")
    login!(mary)
    visit(account_api_keys_path)

    assert_selector("body.api_keys__index")
    within("#account_api_keys_form") do
      assert_field("key_#{marys_api_key.id}")
      # Does not work because single quote gets converted to "smart" apostrophe
      # and encoded. Capybara not smart enough to tell they are equivalent.
      # assert_selector("#key_notes_#{marys_api_key.id} span.current_notes",
      #                 text: marys_api_key.notes.t)
    end
    # Add a new api key
    within("#account_new_api_key_form") do
      fill_in("key_notes", with: "New key idea")
      click_commit
    end

    # Should re-render the index
    assert_selector("body.api_keys__index")
    new_api_key = APIKey.last
    within("#account_api_keys_form") do
      assert_field("key_#{new_api_key.id}")
      assert_selector("#key_notes_#{new_api_key.id} span.current_notes",
                      text: "New key idea")
    end
    within("#key_notes_#{new_api_key.id}") do
      click_on("Edit")
    end

    # We're just testing the no-js version of the edit form, here
    assert_selector("body.api_keys__edit")
    within("#account_edit_api_key_form") do
      # Change the notes
      fill_in("key_notes", with: "Reconsidered key idea")
      click_commit
    end

    # Should re-render the index
    assert_selector("body.api_keys__index")
    within("#account_api_keys_form") do
      assert_field("key_#{new_api_key.id}")
      assert_selector("#key_notes_#{new_api_key.id} span.current_notes",
                      text: "Reconsidered key idea")
      has_no_checked_field?("key_#{new_api_key.id}")
      has_no_checked_field?("key_#{marys_api_key.id}")
      # Remove the first api key
      check("key_#{marys_api_key.id}")
      click_commit
    end

    # Should re-render the index
    assert_selector("body.api_keys__index")
    within("#account_api_keys_form") do
      refute_field("key_#{marys_api_key.id}")
    end
  end

  # API users are supposedly created without a password.
  # Be sure they're sent to choose one
  def test_choose_password
    # new_api_user = users("unverified_api_user")
    # visit(account_verify_path(id: new_api_user.id,
    #                           auth_code: new_api_user.auth_code))
    # binding.break

    # assert_flash_text(:account_choose_password_warning.t)
    # within("#account_choose_password_form") do
    #   fill_in("user_password", with: "something")
    #   click_commit
    # end

    # assert_equal(new_api_user.password, User.sha1("something"))
    # binding.break
  end

  def test_signup; end
end
