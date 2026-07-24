# frozen_string_literal: true

require("application_system_test_case")

# Regression tests for issue #4884: the "Show Original Image" and
# "Show EXIF Header" links at the bottom of the lightbox caption were
# dead. The caption embedded the image vote interface, and the global
# `.vote-section` thumbnail hover-overlay styling (absolute
# bottom-pinned, opacity 0) leaked into `.lg-sub-html`, leaving an
# invisible strip covering the links row and swallowing every click.
# The caption's own vote UI (restored properly in #4886/#4892) uses a
# distinct `.vote-section-lightbox` class -- dark background, no
# absolute positioning -- specifically so this can't recur; clicking
# each link here fails with Cuprite's "another element would receive
# the click" error if the unsafe `.vote-section` flavor ever comes
# back. The caption itself is a real, hidden DOM element nested in the
# theater-btn now, not a captured-HTML clone in `data-sub-html` (#4894).
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

    # The caption's own vote UI is `.vote-section-lightbox`, not the
    # unsafe hover-overlay `.vote-section` — see class comment.
    within(".lg-sub-html") do
      assert_no_selector(".vote-section", visible: :all)
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
