# frozen_string_literal: true

require("test_helper")

# tests of Transformations controller
module Images
  class TransformationsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

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

    # A full-page redirect on a Turbo request tears down and
    # re-subscribes the image show page's Action Cable subscription,
    # dropping RotateImageJob's async broadcast if it lands during
    # that gap (#4854). A turbo_stream request must not redirect, and
    # must still surface the flash notice (a plain 204 discarded it
    # silently instead of rendering it).
    def test_transform_turbo_stream_does_not_redirect
      image = images(:in_situ_image)
      user = image.user
      params = { id: image.id, op: "rotate_left", size: user.image_size }

      login(user.login)
      put(:update, params: params, format: :turbo_stream)

      assert_response(:success)
      assert_select("turbo-stream[action='update'][target='page_flash']")
      assert_select("#flash_notices", text: :image_show_transform_note.l)
    end

    # Real file + real job run, unlike run_transform above -- confirms
    # rotation actually swapped width/height, not just the flash text.
    def test_transform_rotate_swaps_dimensions
      image = images(:in_situ_image)
      seed_real_image_file(image) # 1600x1200

      login(image.user.login)
      perform_enqueued_jobs do
        put(:update, params: { id: image.id, op: "rotate_left",
                               size: image.user.image_size })
      end

      image.reload
      assert_equal(1200, image.width)
      assert_equal(1600, image.height)
    end
  end
end
