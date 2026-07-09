# frozen_string_literal: true

require("test_helper")

class ImageDhashJobTest < ActiveJob::TestCase
  def test_computes_and_stores_dhash
    unless system("command -v convert >/dev/null 2>&1")
      skip("ImageMagick `convert` not available")
    end

    image = images(:in_situ_image)
    # Point the test-env original fallback at a real fixture file.
    image.update_columns(original_name: "Coprinus_comatus.jpg")

    assert_nil(image.dhash)
    ImageDhashJob.perform_now(image.id)

    assert_not_nil(image.reload.dhash)
  end

  def test_missing_image_is_a_noop
    assert_nothing_raised { ImageDhashJob.perform_now(-1) }
  end
end
