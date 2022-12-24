# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Account::Profile
  class ImagesControllerTest < FunctionalTestCase
    # Prove there is no change when user tries to change profile image to itself
    def test_reuse_user_profile_image_as_itself
      user = users(:rolf)
      assert((img = user.image), "Test needs User fixture with profile image")
      params = { id: img.id }

      login(user.login)
      get(:reuse, params: params)

      assert_equal(img, user.image)
      assert_flash_text(:runtime_no_changes.l)
    end

    # This is what would happen when user first opens form.
    def test_reuse_image_for_user_page_access
      requires_login(:reuse)
      assert_template("reuse", partial: "shared/_images_to_reuse")
      assert_form_action(action: :attach)
    end

    # This would happen if user clicked on image.
    def test_reuse_image_for_user_post1
      image = images(:commercial_inquiry_image)
      params = { id: image.id.to_s }
      post_requires_login(:attach, params)
      assert_redirected_to(user_path(rolf.id))
      assert_equal(rolf.id, session[:user_id])
      assert_equal(image.id, rolf.reload.image_id)
    end

    # This would happen if user typed in id and submitted.
    def test_reuse_image_for_user_post2
      image = images(:commercial_inquiry_image)
      params = { id: image.id.to_s }
      post_requires_login(:attach, params)
      assert_redirected_to(user_path(rolf.id))
      assert_equal(rolf.id, session[:user_id])
      assert_equal(image.id, rolf.reload.image_id)
    end
  end
end
