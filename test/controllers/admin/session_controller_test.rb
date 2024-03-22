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
  end
end
