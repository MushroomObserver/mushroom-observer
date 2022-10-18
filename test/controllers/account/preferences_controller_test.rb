# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
class Account::PreferencesControllerTest < FunctionalTestCase
  def test_edit
    # First make sure it can serve the form to start with.
    get("edit")
    assert_redirected_to(account_login_path)
    login
    get("edit")
    Language.all.each do |lang|
      assert_select("option[value=#{lang.locale}]", { count: 1 },
                    "#{lang.locale} language option missing")
    end
    assert_input_value(:user_login, "rolf")
    assert_input_value(:user_email, "rolf@collectivesource.com")
    assert_input_value(:user_password, "")
    assert_input_value(:user_password_confirmation, "")
    assert_input_value(:user_thumbnail_maps, "1")
    assert_input_value(:user_view_owner_id, "1")
    assert_input_value(:user_has_images, "")
    assert_input_value(:user_has_specimen, "")
    assert_input_value(:user_lichen, nil)
    assert_input_value(:user_region, "")
    assert_input_value(:user_clade, "")

    # Now change everything.
    params = {
      login: "rolf",
      password: "new_password",
      password_confirmation: "new_password",
      email: "new@email.com",
      email_comments_all: "",
      email_comments_owner: "1",
      email_comments_response: "1",
      email_general_commercial: "1",
      email_general_feature: "1",
      email_general_question: "1",
      email_html: "1",
      email_locations_admin: "1",
      email_locations_all: "",
      email_locations_author: "1",
      email_locations_editor: "",
      email_names_admin: "1",
      email_names_all: "",
      email_names_author: "1",
      email_names_editor: "",
      email_names_reviewer: "1",
      email_observations_all: "",
      email_observations_consensus: "1",
      email_observations_naming: "1",
      hide_authors: "above_species",
      keep_filenames: "keep_but_hide",
      license_id: licenses(:publicdomain).id.to_s,
      layout_count: "100",
      locale: "el",
      location_format: "scientific",
      notes_template: "Collector's #",
      theme: "Agaricus",
      thumbnail_maps: "",
      view_owner_id: "",
      votes_anonymous: "yes",
      has_images: "1",
      has_specimen: "1",
      lichen: "yes",
      region: "California",
      clade: "Ascomycota"
    }

    # Prove that all the values are initialized correctly if reloading form.
    patch(:update,
          params: { user: params.merge(password_confirmation: "bogus") })
    assert_flash_error
    assert_response(:success)
    # Rails gives a 204 response to the patch request here, and that response
    # has no message body. 204 means patch not accepted, but form not changed,
    # keep editing.
    # The lack of response body means the following assertions cannot work.
    # Rails only tests against the current response. Maybe we can store response
    # body and restore it? Otherwise, move these to an integration test.
    # Incidentally rails.ujs disables the button on submit, and does not
    # re-enable it after the 204.
    assert_input_value(:user_password, "")
    assert_input_value(:user_password_confirmation, "")
    assert_input_value(:user_email, "new@email.com")
    assert_input_value(:user_email_comments_all, "")
    assert_input_value(:user_email_comments_owner, "1")
    assert_input_value(:user_email_comments_response, "1")
    assert_input_value(:user_email_general_commercial, "1")
    assert_input_value(:user_email_general_feature, "1")
    assert_input_value(:user_email_general_question, "1")
    assert_input_value(:user_email_html, "1")
    assert_input_value(:user_email_locations_admin, "1")
    assert_input_value(:user_email_locations_all, "")
    assert_input_value(:user_email_locations_author, "1")
    assert_input_value(:user_email_locations_editor, "")
    assert_input_value(:user_email_names_admin, "1")
    assert_input_value(:user_email_names_all, "")
    assert_input_value(:user_email_names_author, "1")
    assert_input_value(:user_email_names_editor, "")
    assert_input_value(:user_email_names_reviewer, "1")
    assert_input_value(:user_email_observations_all, "")
    assert_input_value(:user_email_observations_consensus, "1")
    assert_input_value(:user_email_observations_naming, "1")
    assert_input_value(:user_hide_authors, "above_species")
    assert_input_value(:user_keep_filenames, "keep_but_hide")
    assert_input_value(:user_license_id, licenses(:publicdomain).id.to_s)
    assert_input_value(:user_layout_count, "100")
    assert_input_value(:user_locale, "el")
    assert_input_value(:user_location_format, "scientific")
    assert_textarea_value(:user_notes_template, "Collector's #")
    assert_input_value(:user_theme, "Agaricus")
    assert_input_value(:user_thumbnail_maps, "")
    assert_input_value(:user_view_owner_id, "")
    assert_input_value(:user_votes_anonymous, "yes")
    assert_input_value(:user_has_images, "1")
    assert_input_value(:user_has_specimen, "1")
    assert_input_value(:user_lichen, "yes")
    assert_input_value(:user_region, "California")
    assert_input_value(:user_clade, "Ascomycota")

    # Now do it correctly, and make sure changes were made.
    patch(:update, params: { user: params })
    assert_flash_text(:runtime_prefs_success.t)
    user = rolf.reload
    assert_equal("new@email.com", user.email)
    assert_equal(false, user.email_comments_all)
    assert_equal(true, user.email_comments_owner)
    assert_equal(true, user.email_comments_response)
    assert_equal(true, user.email_general_commercial)
    assert_equal(true, user.email_general_feature)
    assert_equal(true, user.email_general_question)
    assert_equal(true, user.email_html)
    assert_equal(true, user.email_locations_admin)
    assert_equal(false, user.email_locations_all)
    assert_equal(true, user.email_locations_author)
    assert_equal(false, user.email_locations_editor)
    assert_equal(true, user.email_names_admin)
    assert_equal(false, user.email_names_all)
    assert_equal(true, user.email_names_author)
    assert_equal(false, user.email_names_editor)
    assert_equal(true, user.email_names_reviewer)
    assert_equal(false, user.email_observations_all)
    assert_equal(true, user.email_observations_consensus)
    assert_equal(true, user.email_observations_naming)
    assert_equal("above_species", user.hide_authors)
    assert_equal("keep_but_hide", user.keep_filenames)
    assert_equal(100, user.layout_count)
    assert_equal(licenses(:publicdomain), user.license)
    assert_equal("el", user.locale)
    assert_equal("scientific", user.location_format)
    assert_equal("Collector's #", user.notes_template)
    assert_equal("Agaricus", user.theme)
    assert_equal(false, user.thumbnail_maps)
    assert_equal(false, user.view_owner_id)
    assert_equal("yes", user.votes_anonymous)
    assert_equal("yes", user.content_filter[:has_images])
    assert_equal("yes", user.content_filter[:has_specimen])
    assert_equal("yes", user.content_filter[:lichen])
    assert_equal("California", user.content_filter[:region])
    assert_equal("Ascomycota", user.content_filter[:clade])

    # Prove user cannot pick "Other" as a notes_template heading
    old_notes_template = user.notes_template
    # prior test set the locale to Greece
    # reset locale to get less incomprehensible error messages
    user.locale = "en"
    user.save
    patch(:update,
          params: { user: params.merge(notes_template: "Size, Other") })
    assert_flash_error
    assert_equal(old_notes_template, user.reload.notes_template)

    # Prove user cannot have duplicate headings in notes template
    patch(:update,
          params: { user: params.merge(notes_template: "Yadda, Yadda") })
    assert_flash_error
    assert_equal(old_notes_template, user.reload.notes_template)

    # Prove login can't already exist.
    patch(:update, params: { user: params.merge(login: "mary") })
    assert_flash_error
    assert_equal("rolf", user.reload.login)

    # But does work if it's new!
    patch(:update, params: { user: params.merge(login: "steve") })
    assert_equal("steve", user.reload.login)

    # Prove password was changed correctly somewhere along the line.
    logout

    @controller = AccountController.new
    post(:login,
         params: { user: { login: "steve", password: "new_password" } })
    assert_equal(rolf.id, @request.session["user_id"])
  end
end
