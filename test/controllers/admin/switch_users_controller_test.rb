# frozen_string_literal: true

require("test_helper")

module Admin
  class SwitchUsersControllerTest < FunctionalTestCase
    def test_switch_users
      get(:new)
      assert_response(:redirect)

      login(:rolf)
      get(:new)
      assert_response(:redirect)

      rolf.admin = true
      rolf.save!
      get(:new)
      assert_response(:success)

      assert_users_equal(rolf, User.current)
      post(:create, params: { id: "unverified" })
      assert_users_equal(rolf, User.current)
      assert_flash(/not verified yet/)
      post(:create, params: { id: "Frosted Flake" })
      assert_users_equal(rolf, User.current)
      post(:create, params: { id: mary.id })
      assert_users_equal(mary, User.current)
      post(:create, params: { id: dick.login })
      assert_users_equal(dick, User.current)
      post(:create, params: { id: mary.email })
      assert_users_equal(mary, User.current)
    end
  end
end
