# frozen_string_literal: true

require("test_helper")

module Account
  class LogoutControllerTest < FunctionalTestCase
    def setup
      @request.host = "localhost"
      super
    end

    def test_show_renders_logout_page
      get(:show)

      assert_response(:success)
      assert_head_title(:logout_title.l)
    end

    def test_create_clears_session_and_redirects
      login
      assert_not_nil(@request.session[:user_id])

      post(:create)

      assert_nil(@request.session[:user_id],
                 "Session user_id should be nil after logout")
      assert_redirected_to(account_logout_path)
    end

    # `switch_to_user` lives in ApplicationController::Authentication.
    # The logout `create` action is the primary caller — exercise it here.
    # Covers the `session[:real_user_id].blank?` branch (sets real_user_id
    # from current user). `@user` is set here because in a real request
    # `autologin`'s before_action always sets it before any action runs.
    def test_switch_to_user_with_blank_real_user_id_sets_session
      ctrl = @controller
      session.clear
      ctrl.instance_variable_set(:@user, users(:rolf))
      target = users(:mary)

      ctrl.send(:switch_to_user, target)

      assert_equal(users(:rolf).id, session[:real_user_id])
      assert_equal(users(:rolf).auth_code, session[:real_auth])
      assert_nil(session[:admin])
      assert_equal(target, ctrl.instance_variable_get(:@user))
    end

    # Covers the `elsif session[:real_user_id] == new_user.id` branch in
    # `update_sudo_session` — when the admin returns to their real account,
    # real_user_id is cleared and admin mode is restored.
    def test_switch_to_user_clears_real_user_id_when_returning_to_real_account
      ctrl = @controller
      rolf = users(:rolf)
      session[:real_user_id] = rolf.id

      ctrl.send(:switch_to_user, rolf)

      assert_nil(session[:real_user_id])
      assert_nil(session[:real_auth])
      assert(session[:admin])
    end

    # The switched session can produce the credential stored at switch
    # time, so the admin comes back with admin mode on.
    def test_create_restores_the_admin_behind_a_switched_session
      rolf.update!(admin: true)
      login("mary")
      session[:real_user_id] = rolf.id
      session[:real_auth] = rolf.auth_code

      post(:create)

      assert_equal(rolf.id, session[:user_id])
      assert_equal(true, session[:admin])
      assert_nil(session[:real_user_id])
    end

    # A session carrying only the id -- one predating the binding, or a
    # copy of a switched session whose admin has since rotated -- is
    # logged out instead of promoted.
    def test_create_refuses_a_sudo_session_with_no_credential
      rolf.update!(admin: true)
      login("mary")
      session[:real_user_id] = rolf.id

      post(:create)

      assert_nil(session[:user_id])
      assert_nil(session[:real_user_id])
      assert_equal(false, session[:admin])
      assert_redirected_to(account_logout_path)
    end

    def test_create_refuses_a_sudo_session_with_a_stale_credential
      rolf.update!(admin: true)
      login("mary")
      session[:real_user_id] = rolf.id
      session[:real_auth] = rolf.auth_code
      rolf.change_password("something else")

      post(:create)

      assert_nil(session[:user_id])
      assert_nil(session[:real_user_id])
      assert_redirected_to(account_logout_path)
    end

    # `session_user_set(nil)` owns the clearing, so an ordinary logout
    # leaves nothing behind for the branch above to act on.
    def test_create_clears_sudo_keys_on_an_ordinary_logout
      login("mary")
      session[:real_user_id] = users(:dick).id
      session[:real_auth] = users(:dick).auth_code

      post(:create)

      assert_nil(session[:real_user_id])
      assert_nil(session[:real_auth])
      assert_equal(false, session[:admin])
    end
  end
end
