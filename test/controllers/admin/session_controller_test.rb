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

      assert_users_equal(rolf, User.current)
      put(:update, params: { id: "unverified" })
      assert_users_equal(rolf, User.current)
      assert_flash(/not verified yet/)
      put(:update, params: { id: "Frosted Flake" })
      assert_users_equal(rolf, User.current)
      put(:update, params: { id: mary.id })
      assert_users_equal(mary, User.current)
      put(:update, params: { id: dick.login })
      assert_users_equal(dick, User.current)
      put(:update, params: { id: mary.email })
      assert_users_equal(mary, User.current)
    end

    # Test form submission with namespaced params (from Phlex form)
    def test_switch_users_with_form_params
      login(:rolf)
      rolf.admin = true
      rolf.save!

      assert_users_equal(rolf, User.current)
      # Text input field submits as :user
      put(:update, params: { admin_session: { user: mary.login } })
      assert_users_equal(mary, User.current)
    end

    # Test autocompleter submission with user_id hidden field
    def test_switch_users_with_autocompleter_user_id
      login(:rolf)
      rolf.admin = true
      rolf.save!

      assert_users_equal(rolf, User.current)
      # Autocompleter submits user_id as hidden field
      put(:update, params: { admin_session: { user_id: mary.id } })
      assert_users_equal(mary, User.current)
      assert_redirected_to(action: :edit)
    end

    # Test "Full Name (login)" format from autocompleter text field
    def test_switch_users_with_unique_text_name
      login(:rolf)
      rolf.admin = true
      rolf.save!

      assert_users_equal(rolf, User.current)
      # Autocompleter shows "Full Name (login)" in text field
      put(:update, params: { admin_session: { user: mary.unique_text_name } })
      assert_users_equal(mary, User.current)
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
      assert_users_equal(mary, User.current)
    end
  end
end
