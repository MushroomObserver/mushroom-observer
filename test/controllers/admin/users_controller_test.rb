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

    def test_destroy_user
      # disposable fixture user; `User.erase_user` does the heavy work.
      user = users(:spammer)
      user_id = user.id

      login(:rolf)
      make_admin
      delete(:destroy, params: { id: user_id })

      assert_response(:redirect)
      assert_nil(User.find_by(id: user_id),
                 "User.erase_user should have removed the user")
    end

    def test_destroy_blank_id
      # `if id.present?` guard branch — blank `id` skips the
      # `User.erase_user` call and still redirects.
      login(:rolf)
      make_admin
      delete(:destroy, params: { id: "" })

      assert_response(:redirect)
    end
  end
end
