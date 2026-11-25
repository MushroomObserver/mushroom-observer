# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Account::Profile
  class ImagesControllerTest < FunctionalTestCase
    def test_detach_removes_profile_image
      user = users(:rolf)
      assert(user.image, "Test needs User fixture with profile image")

      login(user.login)
      put(:detach, params: { id: user.id })

      assert_nil(user.reload.image)
      assert_redirected_to(edit_account_profile_path)
      assert_flash_success
    end

    def test_detach_with_no_image_does_nothing
      user = users(:mary)
      assert_nil(user.image, "Test needs User fixture with no profile image")

      login(user.login)
      put(:detach, params: { id: user.id })

      assert_nil(user.reload.image)
      assert_redirected_to(edit_account_profile_path)
      assert_no_flash
    end
  end
end
