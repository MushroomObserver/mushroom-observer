# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Account::Profile
  class ImagesControllerTest < FunctionalTestCase
    def test_detach_removes_profile_image
      user = users(:rolf)
      assert(user.image, "Test needs User fixture with profile image")

      login(user.login)
      put(:detach, params: {})

      assert_nil(user.reload.image)
      assert_flash(:runtime_profile_removed_image)
      assert_redirected_to(edit_account_profile_path)
    end

    def test_detach_with_no_profile_image_is_a_no_op
      user = users(:zero_user)
      assert_nil(user.image, "Test needs User fixture with no profile image")

      login(user.login)
      put(:detach, params: {})

      assert_nil(user.reload.image)
      assert_redirected_to(edit_account_profile_path)
    end
  end
end
