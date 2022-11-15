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
      # needs `CGI.unescapeHTML` because single quote gets converted to "smart"
      # apostrophe and encoded by `t`. Otherwise Capybara will not find the
      # HTML entity `&#8217;` and the character `’` equivalent.
      assert_selector("#key_notes_#{marys_api_key.id} span.current_notes",
                      text: CGI.unescapeHTML(marys_api_key.notes.t))
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

  def test_signup
    visit(account_signup_path)
    assert_selector("body.account__new")
    # Make a mistake with the password confirmation
    within("#account_signup_form") do
      assert_field("new_user_login")
      fill_in("new_user_login", with: "Dumbledore")
      fill_in("new_user_password", with: "Hagrid_24!")
      fill_in("new_user_password_confirmation", with: "Hagrid_24?")
      click_commit
    end

    # We ought to be back at the form
    assert_selector("body.account__new")
    assert_flash_error
    assert_flash_text(CGI.unescapeHTML(:validate_user_password_no_match.t))
    assert_flash_text(:validate_user_email_missing.t)
    # This time, do it right
    within("#account_signup_form") do
      fill_in("new_user_login", with: "Dumbledore")
      fill_in("new_user_password", with: "Hagrid_24!")
      fill_in("new_user_password_confirmation", with: "Hagrid_24!")
      click_commit
    end

    # Ah, but we didn't give an email address.
    assert_selector("body.account__new")
    assert_flash_error
    assert_no_flash_text(CGI.unescapeHTML(:validate_user_password_no_match.t))
    assert_flash_text(:validate_user_email_missing.t)
    within("#account_signup_form") do
      fill_in("new_user_login", with: "Dumbledore")
      fill_in("new_user_password", with: "Hagrid_24!")
      fill_in("new_user_password_confirmation", with: "Hagrid_24!")
      fill_in("new_user_email", with: "Hagrid_24!")
      click_commit
    end

    # That's not an email address.
    assert_flash_error
    assert_flash_text(:validate_user_email_missing.t)
    assert_flash_text(:validate_user_email_confirmation_missing.t)
    within("#account_signup_form") do
      fill_in("new_user_login", with: "Dumbledore")
      fill_in("new_user_password", with: "Hagrid_24!")
      fill_in("new_user_password_confirmation", with: "Hagrid_24!")
      fill_in("new_user_email", with: "Hagrid_24!")
      fill_in("new_user_email_confirmation", with: "Hagrid_24!")
      click_commit
    end

    # That's still not an email address.
    assert_flash_error
    assert_flash_text(:validate_user_email_missing.t)
    within("#account_signup_form") do
      fill_in("new_user_login", with: "Dumbledore")
      fill_in("new_user_password", with: "Hagrid_24!")
      fill_in("new_user_password_confirmation", with: "Hagrid_24!")
      fill_in("new_user_email", with: "webmaster@hogwarts.org")
      fill_in("new_user_email_confirmation", with: "webmaster@hogwarts.org")
      click_commit
    end

    assert_selector("body.account__welcome")
  end
end
