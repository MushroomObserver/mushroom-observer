# frozen_string_literal: true

require("test_helper")

module Admin
  class SessionControllerTest < FunctionalTestCase
    def test_turn_admin_on_and_off
      post(:create, params: { turn_on: true })
      assert_false(session[:admin])
      login(:rolf)
      post(:create, params: { turn_on: true })
      assert_false(session[:admin])
      rolf.admin = true
      rolf.save!
      post(:create, params: { turn_on: true })
      assert_true(session[:admin])

      post(:create, params: { turn_off: true })
      assert_false(session[:admin])
    end

    def test_switch_users
      get(:edit)
      assert_response(:redirect)

      login(:rolf)
      get(:edit)
      assert_response(:redirect)

      rolf.admin = true
      rolf.save!
      get(:edit)
      assert_response(:success)

      assert_users_equal(rolf, logged_in_user)
      put(:update, params: { id: "unverified" })
      assert_users_equal(rolf, logged_in_user)
      assert_flash(/not verified yet/)
      put(:update, params: { id: "Frosted Flake" })
      assert_users_equal(rolf, logged_in_user)
      put(:update, params: { id: mary.id })
      assert_users_equal(mary, logged_in_user)
      put(:update, params: { id: dick.login })
      assert_users_equal(dick, logged_in_user)
      put(:update, params: { id: mary.email })
      assert_users_equal(mary, logged_in_user)
    end

    # Test form submission with namespaced params (from Phlex form)
    def test_switch_users_with_form_params
      login(:rolf)
      rolf.admin = true
      rolf.save!

      assert_equal(rolf.id, session[:user_id])
      # Text input field submits as :user
      put(:update, params: { admin_session: { user: mary.login } })
      assert_users_equal(mary, logged_in_user)
    end

    # Test autocompleter submission with user_id hidden field
    def test_switch_users_with_autocompleter_user_id
      login(:rolf)
      rolf.admin = true
      rolf.save!

      assert_equal(rolf.id, session[:user_id])
      # Autocompleter submits user_id as hidden field
      put(:update, params: { admin_session: { user_id: mary.id } })
      assert_users_equal(mary, logged_in_user)
      assert_redirected_to(action: :edit)
    end

    # Test "Full Name (login)" format from autocompleter text field
    def test_switch_users_with_unique_text_name
      login(:rolf)
      rolf.admin = true
      rolf.save!

      assert_equal(rolf.id, session[:user_id])
      # Autocompleter shows "Full Name (login)" in text field
      put(:update, params: { admin_session: { user: mary.unique_text_name } })
      assert_users_equal(mary, logged_in_user)
    end

    # Non-admin without `session[:real_user_id]` hitting `update` with a
    # valid target user takes the `redirect_back_or_default("/")`
    # branch in the update action. `edit` would redirect such a user
    # away before they ever reach the form; this exercises a direct
    # PUT bypassing that guard.
    def test_update_non_admin_redirected
      login(:rolf)
      # rolf is NOT admin and session[:real_user_id] is blank.
      put(:update, params: { admin_session: { user_id: mary.id } })

      assert_response(:redirect)
      # Should NOT have switched users.
      assert_users_equal(rolf, logged_in_user)
    end

    # Admin in "switch user mode" switching back to themselves: the
    # `elsif session[:real_user_id] == new_user.id` branch in
    # `switch_to_user` resets `:real_user_id` and re-enables admin
    # mode.
    def test_switch_back_to_original_admin
      login(:rolf)
      rolf.admin = true
      rolf.save!

      # Switch from rolf (admin) to mary; now session[:real_user_id]
      # holds rolf.id and session[:admin] is nil.
      put(:update, params: { admin_session: { user_id: mary.id } })
      assert_users_equal(mary, logged_in_user)

      # Switch back to rolf — hits the "real_user_id == new_user.id"
      # branch.
      put(:update, params: { admin_session: { user_id: rolf.id } })
      assert_users_equal(rolf, logged_in_user)
      assert_equal(true, session[:admin])
      assert_nil(session[:real_user_id])
    end

    # `find_user_by_id_login_or_email("")` returns `nil` for a blank
    # input. With no params at all, `@id` ends up blank and the
    # method's blank-string branch fires.
    def test_update_with_no_params
      login(:rolf)
      rolf.admin = true
      rolf.save!

      put(:update, params: {})

      # No new_user found; nothing happens. We just need the action
      # to not crash — the blank branch in
      # `find_user_by_id_login_or_email` is what we're covering.
      assert_users_equal(rolf, logged_in_user)
    end

    # Test that update redirects to edit (PRG pattern) so browser URL is correct
    def test_update_redirects_to_edit
      login(:rolf)
      rolf.admin = true
      rolf.save!

      # Switch to mary - should redirect to edit, not render
      put(:update, params: { admin_session: { user_id: mary.id } })
      assert_response(:redirect)
      assert_redirected_to(action: :edit)
      assert_users_equal(mary, logged_in_user)
    end

    private

    def logged_in_user
      @controller.send(:current_user)
    end
  end
end
