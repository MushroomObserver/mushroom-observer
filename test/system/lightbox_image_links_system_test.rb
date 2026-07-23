# frozen_string_literal: true

require("application_system_test_case")

# Regression tests for issue #4884: the "Show Original Image" and
# "Show EXIF Header" links at the bottom of the lightbox caption were
# dead. The global `.vote-section` thumbnail hover-overlay styling
# (absolute bottom-pinned, opacity 0) leaked into `.lg-sub-html`,
# leaving an invisible strip covering the links row and swallowing
# every click. Clicking each link here fails with Cuprite's
# "another element would receive the click" error if that overlay
# ever comes back.
class LightboxImageLinksSystemTest < ApplicationSystemTestCase
  def test_lightbox_original_and_exif_links
    rolf = users("rolf")
    login!(rolf)

    obs = observations(:detailed_unknown_obs)
    image = obs.thumb_image
    stage_original_file(image)

    visit("/#{obs.id}")
    assert_selector("body.observations__show")

    first(".theater-btn", visible: :all).trigger("click")
    assert_selector(".lg-sub-html")

    # The vote interface renders visibly in the caption (not as the
    # thumbnail-style invisible hover overlay).
    within(".lg-sub-html") do
      assert_selector(".vote-section .image-vote-links")
    end

    # EXIF link opens the EXIF modal.
    within(".lg-sub-html") do
      find("a", text: :image_show_exif.t).click
    end
    assert_selector("#modal_image_exif_#{image.id}", wait: 9)
    assert_selector("#modal_image_exif_#{image.id} #exif_data_table")
    within("#modal_image_exif_#{image.id}") do
      first("[data-dismiss='modal']").click
    end
    assert_no_selector("#modal_image_exif_#{image.id} #exif_data_table")

    # Original-image link polls for the original, then opens it in a
    # new window once ready.
    original_window = window_opened_by do
      within(".lg-sub-html") do
        find("a", text: :image_show_original.l).click
      end
    end
    original_window.close
  end

  private

  # The EXIF endpoint shells out to exiftool on the image's local
  # original; stage a real geotagged fixture file so it succeeds.
  def stage_original_file(image)
    fixture = "#{MO.root}/test/images/geotagged.jpg"
    file = image.full_filepath("orig")
    FileUtils.mkdir_p(File.dirname(file))
    FileUtils.cp(fixture, file)
  end
end
