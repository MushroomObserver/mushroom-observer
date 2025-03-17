# frozen_string_literal: true

require("test_helper")

module Admin
  class UsersControllerTest < FunctionalTestCase
    def test_change_bonuses
      user = users(:mary)
      user_stats = user_stats(:mary)
      old_contribution = mary.contribution
      bonus = "7 lucky \n 13 unlucky"

      # Prove that non-admin cannot change bonuses and attempt to do so
      # redirects to "/" (not target user's page)
      login("rolf")
      get(:edit, params: { id: user.id })
      # assert_redirected_to(user_path(user.id))
      assert_redirected_to("/")

      # Prove that admin posting bonuses in wrong format causes a flash error,
      # leaving bonuses and contributions unchanged.
      make_admin
      post(:update, params: { id: user.id, val: "wong format 7" })
      assert_flash_error
      user.reload
      assert_empty(user_stats.bonuses)
      assert_equal(old_contribution, user.contribution)

      # Prove that admin can change bonuses
      post(:update, params: { id: user.id, val: bonus })
      user.reload
      user_stats.reload
      assert_equal([[7, "lucky"], [13, "unlucky"]], user_stats.bonuses)
      assert_equal(old_contribution + 20, user.contribution)

      # Prove that admin can get bonuses
      get(:edit, params: { id: user.id })
      assert_response(:success)
    end
  end
end
