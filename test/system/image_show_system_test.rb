# frozen_string_literal: true

require("application_system_test_case")

class ImageShowSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  # A full-page redirect on a Turbo request tears down and re-subscribes
  # the image show page's Action Cable subscription, dropping
  # RotateImageJob's async broadcast if it lands during that gap (#4854).
  # Reload resets the JS context; a Turbo Stream update doesn't -- so a
  # marker set before the click distinguishes the two. Also confirms
  # rotation actually swapped width/height, not just the flash text.
  def test_rotate_does_not_reload_page
    image = images(:in_situ_image)
    seed_real_image_file(image) # 1600x1200
    login!(image.user)

    visit("/images/#{image.id}")
    assert_selector("body.images__show")

    page.execute_script("window.moTestMarker = true")

    perform_enqueued_jobs do
      click_on(:image_show_rotate_left.l)
    end

    assert_selector("#flash_notices", text: :image_show_transform_note.l)
    assert(page.evaluate_script("window.moTestMarker"),
           "Page reloaded instead of updating via Turbo Stream")

    image.reload
    assert_equal(1200, image.width)
    assert_equal(1600, image.height)
  end
end
