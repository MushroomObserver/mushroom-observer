# frozen_string_literal: true

require("test_helper")

class AccountIntegrationTest < CapybaraIntegrationTestCase
  # -------------------------------
  #  Test basic login.
  # -------------------------------

  def test_login
    # Start at index.
    visit("/")

    # Login.
    first(:link, text: "Login").click
    assert_selector("body.login__new")

    # Try to login without a password.
    within("#account_login_form") do
      assert_field("user_login", text: "")
      assert_field("user_password", text: "")
      assert_checked_field("user_remember_me")
      fill_in("user_login", with: "rolf")
      click_commit
    end
    assert_selector("body.login__create")
    assert_flash_text(/unsuccessful/)

    # Try again with incorrect password.
    within("#account_login_form") do
      assert_field("user_login", with: "rolf")
      assert_field("user_password", text: "")
      assert_checked_field("user_remember_me")
      fill_in("user_password", with: "boguspassword")
      uncheck("user_remember_me")
      click_commit
    end
    assert_selector("body.login__create")
    assert_flash_text(/unsuccessful/)

    # Try yet again with correct password.
    within("#account_login_form") do
      assert_field("user_login", with: "rolf")
      assert_field("user_password", text: "")
      assert_unchecked_field("user_remember_me")
      fill_in("user_password", with: "testpassword")
      click_commit
    end
    assert_selector("body.observations__index")
    assert_flash_text(/success/)

    # This should only be accessible if logged in.
    first(:link, text: "Preferences").click

    assert_selector("body.preferences__edit")

    # Log out and try again.
    first(:button, text: :app_logout.l).click
    assert_selector("body.login__logout")
    assert_no_link(text: "Preferences")
    visit("/account/preferences/edit")
    assert_selector("body.login__new")
  end

  # ----------------------------
  #  Test autologin cookies. To be converted to Capybara
  # ----------------------------

  # def test_autologin
  #   rolf_cookies = get_cookies(rolf, true)
  #   mary_cookies = get_cookies(mary, true)
  #   # Test not working with autologin false
  #   dick_cookies = get_cookies(dick, false)
  #   try_autologin(rolf_cookies, rolf)
  #   try_autologin(mary_cookies, mary)
  #   try_autologin(dick_cookies, false)
  # end

  # def get_cookies(user, autologin)
  #   sess = open_session
  #   login(user, "testpassword", autologin, session: sess)
  #   result = sess.driver.request.cookies.dup
  #   if autologin
  #     assert_match(/^#{user.id}/, result["mo_user"])
  #   else
  #     assert_equal("", result["mo_user"].to_s)
  #   end
  #   result
  # end

  # def try_autologin(cookies, user)
  #   sess = open_session
  #   sess.driver.request.cookies["mo_user"] = cookies["mo_user"]
  #   sess.visit("/account/preferences/edit")
  #   if user
  #     sess.assert_selector("body.preferences__edit")
  #     sess.assert_no_selector("body.login__new")
  #     # assert_users_equal(user, sess.assigns(:user))
  #   else
  #     sess.assert_no_selector("body.preferences__edit")
  #     sess.assert_selector("body.login__new")
  #   end
  # end

  # ------------------------------------------------------------------------
  #  Tests to make sure that the proper links are rendered  on the  home page
  #  when a user is logged in.
  #  test_user_dropdown_avaiable:: tests for existence of dropdown bar & links
  #
  # ------------------------------------------------------------------------

  def test_user_dropdown_avaiable
    login("dick")
    visit("/")
    assert_selector("#user_drop_down")
    links = find_all("#user_drop_down a")
    assert_equal(7, links.length)
  end

  # ----------------------------
  #  Test signup verify login and logout.
  # ----------------------------

  def test_signup_verify_login_and_logout
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
    assert_flash_text(:validate_user_password_no_match.t.as_displayed)
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
    assert_no_flash_text(:validate_user_password_no_match.t.as_displayed)
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

    # Redirected to the Welcome page, but email not verified.
    assert_selector("body.account__welcome")

    # At this point there should be an unverified account for Dumbledore.
    wizard = User.find_by(email: "webmaster@hogwarts.org")
    assert_false(wizard.verified)

    # Actually happens: User tries to sign in immediately, without verifying
    click_link(id: "nav_login_link")
    assert_selector("body.login__new")

    within("#account_login_form") do
      fill_in("user_login", with: wizard.login)
      fill_in("user_password", with: "Hagrid_24!")
      click_commit
    end

    # Rails should send another email with this link.
    verify_mail_content = delivered_mail_html
    assert(verify_mail_content.include?(wizard.login))
    assert(verify_mail_content.include?("verify"))
    # Store the link in that mail, so we can test the reverify link.
    verify_link = first_link_in_mail

    # Should render reverify where they can get another email link. Try it
    click_on("account_reverify_link")
    assert_flash_success(:runtime_reverify_sent.t.strip_squeeze)
    # GOTCHA: last email sent is the webmaster notification for reverify.
    # So check the second to last delivery: delivered_mail_html(2)
    reverify_mail_content = delivered_mail_html(2)
    assert(reverify_mail_content.include?(wizard.login))
    assert(reverify_mail_content.include?("verify"))
    reverify_link = first_link_in_mail(2)

    assert_equal(verify_link, reverify_link)

    # A GET to the verify_link should verify Dumbledore
    visit(verify_link)
    assert_true(wizard.reload.verified)
    # ...and send them to the "new" verifications page
    assert_selector("body.verifications__new")

    # They should be logged in now.
    assert_button(:app_logout.t)
    # Log out. (must use id, there are multiple links)
    click_button(id: "nav_user_logout_link")
    assert_no_link(:app_logout.t)

    # Try to use that verification code again. No can do
    visit(account_verify_email_path(id: wizard.id, auth_code: wizard.auth_code))
    assert_flash_warning(:runtime_reverify_already_verified.t.strip_squeeze)
    assert_selector("body.login__new")

    within("#account_login_form") do
      fill_in("user_login", with: "Dumbledore")
      fill_in("user_password", with: "Hagrid_24!")
      click_commit
    end

    # They should still be able to login (with a button, not a link)
    assert_button(:app_logout.l)
    assert_no_link(:app_logout.l)
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
    assert_flash_text(:validate_user_email_missing.t.as_displayed)
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
    assert_flash_text(:runtime_prefs_password_no_match.t.as_displayed)

    within("#account_preferences_form") do
      fill_in("user_password", with: "wanda")
      fill_in("user_password_confirmation", with: "beverly")
      click_commit
    end
    assert_flash_error
    assert_flash_text(:runtime_prefs_password_no_match.t.as_displayed)

    within("#account_preferences_form") do
      fill_in("user_password", with: "wanda")
      fill_in("user_password_confirmation", with: "wanda")
      click_commit
    end
    assert_flash_success
    assert_selector("body.preferences__edit")
    # End Login settings

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
      select("Full Size", from: "user_image_size")
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
      check("user_with_images")
      check("user_with_specimen")
      select(:prefs_filters_lichen_yes.l, from: "user_lichen")
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
    assert_flash_text(:advanced_search_filter_region.t.as_displayed)

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
      :prefs_notes_template_no_other.t(part: "Other").as_displayed
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

    # Reuse one of mary's images for profile
    assert_nil(mary.image_id)
    visit(edit_account_profile_path)
    click_on(:profile_image_reuse.t)
    first(:button, class: "image-link").click
    assert_not_nil(mary.reload.image_id)

    # Click the button on user profile edit page to remove image
    visit(edit_account_profile_path)
    click_button(:profile_image_remove.t)
    assert_flash_text(:runtime_profile_removed_image.t)
    assert_nil(mary.reload.image_id)
  end
end
