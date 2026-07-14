# frozen_string_literal: true

require("test_helper")

class ImageDhashJobTest < ActiveJob::TestCase
  def test_computes_and_stores_dhash
    unless system("command -v convert >/dev/null 2>&1")
      skip("ImageMagick `convert` not available")
    end

    image = images(:in_situ_image)
    fixture = Rails.root.join("test/images/Coprinus_comatus.jpg").to_s

    assert_nil(image.dhash)
    image.stub(:full_filepath, fixture) do
      Image.stub(:find_by, image) do
        ImageDhashJob.perform_now(image.id)
      end
    end

    assert_not_nil(image.reload.dhash)
  end

  def test_missing_image_is_a_noop
    assert_nothing_raised { ImageDhashJob.perform_now(-1) }
  end
end
