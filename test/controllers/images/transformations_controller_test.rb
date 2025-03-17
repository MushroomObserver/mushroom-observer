# frozen_string_literal: true

require("test_helper")

# tests of Transformations controller
module Images
  class TransformationsControllerTest < FunctionalTestCase
    def test_transform_rotate_left
      run_transform(opr: "rotate_left")
    end

    def test_transform_rotate_right
      run_transform(opr: "rotate_right")
    end

    def test_transform_mirror
      run_transform(opr: "mirror")
    end

    def test_transform_bad_op
      run_transform(opr: "bad_op", flash: %(Invalid operation "bad_op"))
    end

    def run_transform(opr:, flash: :image_show_transform_note.l)
      image = images(:in_situ_image)
      user = image.user
      params = { id: image.id, op: opr, size: user.image_size }

      login(user.login)
      put(:update, params: params)

      # Asserting the flash text is the best I can do because Image.transform
      # does not transform images in the text environment. 2022-08-19 JDC
      assert_flash_text(flash)
      assert_redirected_to(image_path(image.id))
    end
  end
end
