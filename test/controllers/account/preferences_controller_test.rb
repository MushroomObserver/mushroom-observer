# frozen_string_literal: true

require("test_helper")

# tests of Preferences controller
module Account
  class PreferencesControllerTest < FunctionalTestCase
    GOOD_PARAMS = {
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
      image_size: "full_size",
      keep_filenames: "keep_but_hide",
      # license_id: licenses(:publicdomain).id.to_s,
      layout_count: "100",
      locale: "el",
      location_format: "scientific",
      notes_template: "Collector's #",
      theme: "Agaricus",
      thumbnail_maps: "",
      view_owner_id: "",
      votes_anonymous: "yes",
      with_images: "1",
      with_specimen: "1",
      lichen: "yes",
      region: "California, USA",
      clade: "Ascomycota"
    }.freeze

    def test_edit
      # Setup: this licenses fixture only available within test??
      params = GOOD_PARAMS.merge(
        { license_id: licenses(:publicdomain).id.to_s }
      )

      # First make sure it can serve the form to start with.
      requires_login("edit")
      Language.find_each do |lang|
        assert_select("option[value=#{lang.locale}]", { count: 1 },
                      "#{lang.locale} language option missing")
      end
      assert_input_value(:user_login, "rolf")
      assert_input_value(:user_email, "rolf@collectivesource.com")
      assert_input_value(:user_password, "")
      assert_input_value(:user_password_confirmation, "")
      assert_input_value(:user_thumbnail_maps, "1")
      assert_input_value(:user_view_owner_id, "1")
      assert_input_value(:user_image_size, "medium")
      assert_input_value(:user_with_images, "")
      assert_input_value(:user_with_specimen, "")
      assert_input_value(:user_lichen, nil)
      assert_input_value(:user_region, "")
      assert_input_value(:user_clade, "")

      # Now change everything.
      # Prove that all the values are initialized correctly if reloading form.
      patch(:update,
            params: { user: params.merge(password_confirmation: "bogus") })
      assert_flash_error
      assert_response(:success)
      # Rails gives a 204 response to the patch request here, and that response
      # has no message body. 204 means patch not accepted, but form not changed,
      # keep editing. The lack of response body means the following assertions
      # cannot work unless the edit form is re-rendered by the :update action.
      # Rails only tests against the current response. Solution: re-render form.
      # Incidentally rails.ujs disables the button on submit, and does not
      # re-enable it after the 204.
      # We now reenable submit button manually (on form input change) in main.js
      #
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
      assert_input_value(:user_image_size, "full_size")
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
      assert_input_value(:user_with_images, "1")
      assert_input_value(:user_with_specimen, "1")
      assert_input_value(:user_lichen, "yes")
      assert_input_value(:user_region, "California, USA")
      assert_input_value(:user_clade, "Ascomycota")

      # Try a bogus email address
      patch(:update, params: { user: params.merge(email: "bogus") })
      assert_flash_error
      # assert_flash_text(:validate_user_email_missing.t)

      # Try an incomplete region
      patch(:update, params: { user: params.merge(region: "California") })
      assert_flash_error
      # assert_flash_text(:advanced_search_filter_region.t)

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
      assert_equal("full_size", user.image_size)
      assert_equal(licenses(:publicdomain), user.license)
      assert_equal("el", user.locale)
      assert_equal("scientific", user.location_format)
      assert_equal("Collector's #", user.notes_template)
      assert_equal("Agaricus", user.theme)
      assert_equal(false, user.thumbnail_maps)
      assert_equal(false, user.view_owner_id)
      assert_equal("yes", user.votes_anonymous)
      assert_equal("yes", user.content_filter[:with_images])
      assert_equal("yes", user.content_filter[:with_specimen])
      assert_equal("yes", user.content_filter[:lichen])
      assert_equal("California, USA", user.content_filter[:region])
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

      @controller = Account::LoginController.new
      post(:create,
           params: { user: { login: "steve", password: "new_password" } })
      assert_equal(rolf.id, @request.session["user_id"])
    end

    def test_edit_user_with_bogus_email
      # licenses fixture only available within test??
      params = GOOD_PARAMS.merge({ license_id: licenses(:publicdomain).id.to_s,
                                   login: "flintstone" })

      user = users(:flintstone)
      login("flintstone")

      get(:edit)
      assert_input_value(:user_login, "flintstone")
      assert_input_value(:user_email, "bogus")

      # I don't know if we need all the PARAMS, but
      patch(:update, params: { user: params })

      assert_flash_text(:runtime_prefs_success.t)
      assert_equal("new@email.com", user.reload.email)
    end

    def test_edit_prefs_with_email_with_trailing_space
      params = GOOD_PARAMS.merge({ email: " trim@this.com " })
      login("rolf")

      patch(:update, params: { user: params })
      assert_flash_text(:runtime_prefs_success.t)
      assert_equal("trim@this.com", rolf.reload.email)
    end

    def test_edit_user_with_invalid_region
      # licenses fixture only available within test??
      params = GOOD_PARAMS.merge({ license_id: licenses(:publicdomain).id.to_s,
                                   login: "nonregional" })

      user = users(:nonregional)
      login("nonregional")

      get(:edit)
      assert_input_value(:user_login, "nonregional")
      assert_input_value(:user_region, "Massachusetts")

      # I don't know if we need all the PARAMS, but
      patch(:update, params: { user: params })

      assert_flash_text(:runtime_prefs_success.t)
      assert_equal("California, USA", user.reload.content_filter[:region])
    end

    def test_no_email_hooks
      [
        :comments_owner,
        :comments_response,
        :comments_all,
        :observations_consensus,
        :observations_naming,
        :observations_all,
        :names_author,
        :names_editor,
        :names_reviewer,
        :names_all,
        :locations_author,
        :locations_editor,
        :locations_all,
        :general_feature,
        :general_commercial,
        :general_question
      ].each do |type|
        assert_request(
          action: "no_email",
          params: { id: rolf.id, type: type },
          require_login: true,
          require_user: :index,
          result: "no_email"
        )
        assert_not(rolf.reload.send(:"email_#{type}"))
      end
    end

    def test_no_email_failed_save
      login("rolf")
      user = users(:rolf)
      user.stub(:save, false) do
        User.stub(:safe_find, user) do
          get(:no_email, params: { id: rolf.id, type: :comments_owner })

          assert_true(rolf.reload.email_comments_owner,
                      "Preferences should be unchanged when user.save fails")
        end
      end
    end
  end
end
