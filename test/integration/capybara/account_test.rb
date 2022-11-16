# frozen_string_literal: true

require("test_helper")

class AccountTest < CapybaraIntegrationTestCase
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

  def test_correct_invalid_preferences
    flintstone = users("flintstone")
    login!(flintstone)

    visit(edit_account_preferences_path)
    assert_selector("body.preferences__edit")
    within("#account_preferences_form") do
      fill_in("user_email", with: "valid@seemingly.com")
      click_commit
    end

    assert_no_flash_errors
    assert_selector("body.preferences__edit")

    # This user has an invalid region AND a bogus email
    nonregional = users("nonregional")
    login!(nonregional)

    visit(edit_account_preferences_path)
    assert_selector("body.preferences__edit")
    within("#account_preferences_form") do
      fill_in("user_region", with: "Canada") # Use country with a fixture!
      fill_in("user_email", with: "badonkadonk")
      click_commit
    end

    assert_flash_error
    assert_flash_text(CGI.unescapeHTML(:validate_user_email_missing.t))
    within("#account_preferences_form") do
      fill_in("user_region", with: "Canada")
      fill_in("user_email", with: "valid@seemingly.com")
      click_commit
    end

    assert_no_flash_errors
    assert_selector("body.preferences__edit")
  end

  def test_edit_preferences
    mary = users("mary")
    login!(mary)

    # cheating: going direct instead of using selenium just to click a dropdown
    visit(edit_account_preferences_path)

    assert_selector("body.preferences__edit")
    # Login settings
    within("#account_preferences_form") do
      fill_in("user_login", with: "yabba dabba doo")
      click_commit
    end

    mary.reload
    assert_equal(mary.login, "yabba dabba doo")

    assert_flash_success
    assert_selector("body.preferences__edit")
    within("#account_preferences_form") do
      fill_in("user_email", with: "yabba dabba doo")
      click_commit
    end

    assert_flash_error
    assert_flash_text(:validate_user_email_missing.t)
    within("#account_preferences_form") do
      fill_in("user_email", with: "yabba@dabba.doo")
      click_commit
    end

    assert_flash_success
    assert_selector("body.preferences__edit")
    within("#account_preferences_form") do
      fill_in("user_password", with: "wanda")
      click_commit
    end

    assert_flash_error
    assert_flash_text(CGI.unescapeHTML(:runtime_prefs_password_no_match.t))
    within("#account_preferences_form") do
      fill_in("user_password", with: "wanda")
      fill_in("user_password_confirmation", with: "beverly")
      click_commit
    end

    assert_flash_error
    assert_flash_text(CGI.unescapeHTML(:runtime_prefs_password_no_match.t))
    within("#account_preferences_form") do
      fill_in("user_password", with: "wanda")
      fill_in("user_password_confirmation", with: "wanda")
      click_commit
    end
    # End Login settings

    assert_flash_success
    assert_selector("body.preferences__edit")
    # Privacy settings
    within("#account_preferences_form") do
      select("Always anonymous", from: "user_votes_anonymous")
      select("remove from database completely", from: "user_keep_filenames")
      select("Public Domain", from: "user_license_id")
      click_commit
    end

    assert_flash_success
    assert_selector("body.preferences__edit")
    # Appearance settings
    within("#account_preferences_form") do
      select("hide author for genus and higher ranks",
             from: "user_hide_authors")
      select("Postal (New York, USA)", from: "user_location_format")
      select("Agaricus", from: "user_theme")
      assert_select("user_locale",
                    with_options: %w[Ελληνικά English Français Español])
      select("Ελληνικά", from: "user_locale")
      uncheck("user_thumbnail_maps")
      uncheck("user_view_owner_id")
      fill_in("user_layout_count", with: 45)
      click_commit
    end

    assert_flash_success
    assert_selector("body.preferences__edit")
    # Content filters
    within("#account_preferences_form") do
      check("user_has_images")
      check("user_has_specimen")
      select("Show only lichens", from: "user_lichen")
      click_commit
    end

    assert_flash_success
    assert_selector("body.preferences__edit")
    # Content filters
    within("#account_preferences_form") do
      # Region filter - must be end of location string to work,
      # **** including the country ****. There's no autocomplete yet.
      # User must type or paste wisely. This won't pass:
      fill_in("user_region", with: "Gloucester, Massachusetts")
      click_commit
    end

    assert_flash_error
    assert_flash_text(CGI.unescapeHTML(:advanced_search_filter_region.t))
    within("#account_preferences_form") do
      fill_in("user_region", with: "Massachusetts, USA")
      click_commit
    end

    mary.reload
    assert_equal(mary.content_filter[:region], "Massachusetts, USA")

    assert_flash_success
    assert_selector("body.preferences__edit")
    within("#account_preferences_form") do
      fill_in("user_region", with: "")
      click_commit
    end

    assert_flash_success
    assert_selector("body.preferences__edit")
    # Notes - Try a reserved word:
    within("#account_preferences_form") do
      fill_in("user_notes_template", with: "Smells, Textures, Other")
      click_commit
    end

    assert_flash_error
    assert_flash_text(
      CGI.unescapeHTML(:prefs_notes_template_no_other.t(part: "Other"))
    )
    within("#account_preferences_form") do
      fill_in("user_notes_template", with: "Smells, Textures, Impressions")
      click_commit
    end

    assert_flash_success
    assert_selector("body.preferences__edit")
    # Email prefs - flip them all
    within("#account_preferences_form") do
      uncheck("user_email_html")

      uncheck("user_email_comments_owner")
      uncheck("user_email_comments_response")
      check("user_email_comments_all")

      uncheck("user_email_observations_consensus")
      uncheck("user_email_observations_naming")
      check("user_email_observations_all")

      uncheck("user_email_names_admin")
      uncheck("user_email_names_author")
      uncheck("user_email_names_editor")
      uncheck("user_email_names_reviewer")
      check("user_email_names_all")

      uncheck("user_email_locations_admin")
      uncheck("user_email_locations_author")
      uncheck("user_email_locations_editor")
      check("user_email_locations_all")

      uncheck("user_email_general_commercial")
      uncheck("user_email_general_feature")
      uncheck("user_email_general_question")
      click_commit
    end

    assert_flash_success
    assert_selector("body.preferences__edit")

    mary.reload
    assert_equal(mary.email_html, false)
    assert_equal(mary.email_comments_owner, false)
    assert_equal(mary.email_comments_all, true)
    assert_equal(mary.email_observations_all, true)
    assert_equal(mary.email_locations_all, true)
    assert_equal(mary.email_names_all, true)
    assert_equal(mary.email_general_question, false)
    assert_equal(mary.email_general_feature, false)
  end

  def test_profile
    mary = users("mary")
    login!(mary)

    visit(edit_account_profile_path)

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
end
