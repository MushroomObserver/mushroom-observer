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
      email_comments_owner: "1",
      email_comments_response: "1",
      email_general_commercial: "1",
      email_general_feature: "1",
      email_general_question: "1",
      email_html: "1",
      email_locations_admin: "1",
      email_locations_author: "1",
      email_locations_editor: "",
      email_names_admin: "1",
      email_names_author: "1",
      email_names_editor: "",
      email_names_reviewer: "1",
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
      has_images: "1",
      has_specimen: "1",
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
      assert_input_value(:user_has_images, "")
      assert_input_value(:user_has_specimen, "")
      # Phlex's `select_field` marks the empty-value "filter off" option
      # as selected when `content_filter[:lichen]` is nil (post-conversion).
      # ERB's pre-conversion output left the option unmarked. Visually
      # identical (browsers default to first option either way).
      assert_input_value(:user_lichen, "")
      assert_input_value(:user_region, "")
      assert_input_value(:user_clade, "")

      # Now change everything.
      # Prove that all the values are initialized correctly if reloading form.
      patch(:update,
            params: { user: params.merge(password_confirmation: "bogus") })
      assert_flash_error
      assert_unprocessable
      assert_select("form[data-turbo='true']")
      # 422 re-renders the edit form with the submitted values still
      # filled in, so the following assertions check that re-render.
      assert_input_value(:user_password, "")
      assert_input_value(:user_password_confirmation, "")
      assert_input_value(:user_email, "new@email.com")
      assert_input_value(:user_email_comments_owner, "1")
      assert_input_value(:user_email_comments_response, "1")
      assert_input_value(:user_email_general_commercial, "1")
      assert_input_value(:user_email_general_feature, "1")
      assert_input_value(:user_email_general_question, "1")
      assert_input_value(:user_email_html, "1")
      assert_input_value(:user_email_locations_admin, "1")
      assert_input_value(:user_email_locations_author, "1")
      assert_input_value(:user_email_locations_editor, "")
      assert_input_value(:user_email_names_admin, "1")
      assert_input_value(:user_email_names_author, "1")
      assert_input_value(:user_email_names_editor, "")
      assert_input_value(:user_email_names_reviewer, "1")
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
      assert_input_value(:user_has_images, "1")
      assert_input_value(:user_has_specimen, "1")
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
      assert_flash(:runtime_prefs_success)
      user = rolf.reload
      assert_equal("new@email.com", user.email)
      assert_equal(true, user.email_comments_owner)
      assert_equal(true, user.email_comments_response)
      assert_equal(true, user.email_general_commercial)
      assert_equal(true, user.email_general_feature)
      assert_equal(true, user.email_general_question)
      assert_equal(true, user.email_html)
      assert_equal(true, user.email_locations_admin)
      assert_equal(true, user.email_locations_author)
      assert_equal(false, user.email_locations_editor)
      assert_equal(true, user.email_names_admin)
      assert_equal(true, user.email_names_author)
      assert_equal(false, user.email_names_editor)
      assert_equal(true, user.email_names_reviewer)
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
      assert_equal("yes", user.content_filter[:has_images])
      assert_equal("yes", user.content_filter[:has_specimen])
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

      assert_flash(:runtime_prefs_success)
      assert_equal("new@email.com", user.reload.email)
    end

    def test_edit_prefs_with_email_with_trailing_space
      params = GOOD_PARAMS.merge({ email: " trim@this.com " })
      login("rolf")

      patch(:update, params: { user: params })
      assert_flash(:runtime_prefs_success)
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

      assert_flash(:runtime_prefs_success)
      assert_equal("California, USA", user.reload.content_filter[:region])
    end

    def test_has_bulk_license_updater
      login
      get(:edit)
      assert_select("a[href='#{images_edit_licenses_path}']")
    end

    def test_no_email_hooks
      [
        :comments_owner,
        :comments_response,
        :observations_consensus,
        :observations_naming,
        :names_author,
        :names_editor,
        :names_reviewer,
        :locations_author,
        :locations_editor,
        :general_feature,
        :general_commercial,
        :general_question
      ].each do |type|
        login("rolf")
        get(:no_email, params: { id: rolf.id, type: type })
        # Phlex view, so `assert_template` would no-op; use a body
        # marker class instead.
        assert_response(:success)
        assert_select("body.preferences__no_email")
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

    # "Save these as my defaults" on the RSS-logs filter form submits
    # q[types][], not user[default_rss_type] directly.
    def test_normalize_rss_type_list_param
      login("rolf")

      patch(:update,
            params: { q: { types: %w[name observation] } },
            format: :turbo_stream)

      assert_equal("name observation", rolf.reload.default_rss_type)
    end

    # Selecting "Everything" checks every type box (type_checked? in
    # type_filters.rb treats @types == ["all"] as "check them all"),
    # so Save Defaults submits every individual type tag. Collapses
    # back to "all" instead of storing every tag individually.
    def test_update_selecting_everything_collapses_to_all
      login("rolf")

      patch(:update,
            params: { q: { types: RssLog::ALL_TYPE_TAGS.map(&:to_s) },
                      back: "rss_logs" })

      assert_response(:redirect)
      assert_equal("all", rolf.reload.default_rss_type)
    end

    # Not just "select everything" -- any 5+ types selected (out of
    # the 7 tags) is long enough to exceed the old limit: 40 column,
    # even for a deliberate manual selection that isn't literally
    # "all" and so doesn't collapse to that value.
    def test_update_selecting_all_but_one_does_not_exceed_column_limit
      login("rolf")
      types = RssLog::ALL_TYPE_TAGS.map(&:to_s) - ["name"]

      patch(:update, params: { q: { types: types }, back: "rss_logs" })

      assert_response(:redirect)
      assert_equal(types.join(" "), rolf.reload.default_rss_type)
    end

    # E.g. unchecking every type box before clicking Save Defaults,
    # which submits no q[types]. No user[...] fields either, so
    # params[:user] stays nil; update_password/update_prefs_from_form
    # must not crash on that.
    def test_update_with_empty_params
      login("rolf")

      patch(:update, params: {}, format: :turbo_stream)

      assert_response(:success)
    end

    def test_normalize_rss_type_list_param_rejects_malformed_shape
      login("rolf")
      default_rss_type = rolf.default_rss_type

      patch(:update,
            params: { q: { types: { foo: "bar" } } },
            format: :turbo_stream)

      assert_equal(default_rss_type, rolf.reload.default_rss_type)
    end

    def test_update_partial_submission_preserves_other_prefs
      login("rolf")
      assert_equal(true, rolf.thumbnail_maps)
      assert_equal(true, rolf.email_html)

      patch(:update,
            params: { q: { types: %w[observation] } },
            format: :turbo_stream)

      user = rolf.reload
      assert_equal("observation", user.default_rss_type)
      assert_equal(true, user.thumbnail_maps)
      assert_equal(true, user.email_html)
    end

    def test_update_turbo_stream_success
      login("rolf")

      patch(:update,
            params: { q: { types: %w[observation] } },
            format: :turbo_stream)

      assert_response(:success)
      assert_select("turbo-stream[action='update'][target='page_flash']")
      assert_flash(:runtime_prefs_success)
    end

    def test_update_turbo_stream_failure
      login("rolf")

      patch(:update,
            params: { user: { login: "mary" } },
            format: :turbo_stream)

      assert_response(:success)
      assert_select("turbo-stream[action='update'][target='page_flash']")
      assert_flash_error
      assert_equal("rolf", rolf.reload.login)
    end

    def test_update_html_redirects_to_back_destination
      login("rolf")

      patch(:update,
            params: { q: { types: %w[observation] }, back: "rss_logs" })

      assert_redirected_to(activity_logs_path(q: { types: %w[observation] }))
    end

    def test_update_html_unknown_back_falls_back_to_edit
      login("rolf")

      patch(:update,
            params: { q: { types: %w[observation] }, back: "bogus" })

      assert_redirected_to(action: :edit)
    end

    # Unchecking every type box before clicking Save Defaults submits
    # no q[types] (normalize_rss_type_list_param leaves params[:user]
    # unset) -- combined with the plain-HTML fallback path and
    # back: "rss_logs", confirms back_url's activity_logs_path(q: {
    # types: nil }) call does not raise.
    def test_update_html_no_types_with_back_redirects_cleanly
      login("rolf")

      patch(:update, params: { back: "rss_logs" })

      assert_redirected_to(activity_logs_path(q: { types: nil }))
    end
  end
end
