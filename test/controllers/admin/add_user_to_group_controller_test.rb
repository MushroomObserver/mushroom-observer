# frozen_string_literal: true

require("test_helper")

module Admin
  class AddUserToGroupControllerTest < FunctionalTestCase
    def test_add_user_to_group
      login(:rolf)
      post(:create)
      assert_flash_error

      # Happy path
      make_admin
      post(:create,
           params: { user_name: users(:roy).login,
                     group_name: user_groups(:bolete_users).name })
      assert_flash_success
      assert(users(:roy).in_group?(user_groups(:bolete_users).name))

      # Unhappy paths
      post(:create,
           params: { user_name: users(:roy).login,
                     group_name: user_groups(:bolete_users).name })
      assert_flash_warning # Roy is already a member; we just added him above.

      post(:create,
           params: { user_name: "AbsoluteNonsenseVermslons",
                     group_name: user_groups(:bolete_users).name })
      assert_flash_error

      post(:create,
           params: { user_name: users(:roy).login,
                     group_name: "AbsoluteNonsenseVermslons" })
      assert_flash_error
    end
  end
end
