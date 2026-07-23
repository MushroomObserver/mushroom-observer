# frozen_string_literal: true

require("application_system_test_case")

# Test that carousel images get src attributes populated with base64 data
class ObservationFormCarouselSystemTest < ApplicationSystemTestCase
  def test_uploaded_images_get_base64_src_in_carousel_item_and_thumbnail
    setup_image_dirs
    login!(rolf)

    # Go to new observation form
    visit(new_observation_path)

    # Upload first image
    click_attach_file("Coprinus_comatus.jpg")

    # Wait for JavaScript to process the image
    sleep(2)

    # Check carousel item img has base64 src
    carousel_item_img = first(".carousel-item img.set-src")
    src = carousel_item_img["src"]

    assert(src.present?, "Carousel item img should have src attribute")
    assert(
      src.start_with?("data:image"),
      "Carousel item img src should be base64 data URL, got: #{src[0..50]}"
    )

    # With only 1 image, thumbnails are hidden, so use visible: false
    thumbnail_img = first(".carousel-indicator img.set-src", visible: false)
    thumb_src = thumbnail_img["src"]

    assert(thumb_src.present?, "Thumbnail img should have src attribute")
    assert(
      thumb_src.start_with?("data:image"),
      "Thumbnail img src should be base64 data URL, got: #{thumb_src[0..50]}"
    )
  end

  def test_second_uploaded_image_also_gets_base64_src
    setup_image_dirs
    login!(rolf)

    visit(new_observation_path)

    # Upload first image
    click_attach_file("Coprinus_comatus.jpg")
    sleep(0.5)

    # Wait for first carousel item to appear
    assert_selector(".carousel-item[data-image-status='upload']", count: 1,
                                                                  wait: 10)

    # Upload second image
    click_attach_file("geotagged.jpg")
    sleep(0.5)

    # Wait for second carousel item to appear
    # (use visible: :all since carousel hides inactive items)
    assert_selector(
      ".carousel-item[data-image-status='upload']",
      count: 2, wait: 10, visible: :all
    )

    # Should have 2 carousel items with images (check all, even hidden ones)
    carousel_imgs = all(".carousel-item img.set-src", visible: :all)
    assert_equal(2, carousel_imgs.length, "Should have 2 carousel item images")

    # Both should have base64 src
    carousel_imgs.each_with_index do |img, i|
      src = img["src"]
      assert(src.present?, "Image #{i + 1} should have src")
      assert(src.start_with?("data:image"),
             "Image #{i + 1} src should be base64, got: #{src[0..50]}")
    end

    # Should have 2 thumbnails with images (check all, even if hidden)
    thumbnail_imgs = all(".carousel-indicator img.set-src", visible: :all)
    assert_equal(2, thumbnail_imgs.length, "Should have 2 thumbnail images")

    # Both should have base64 src
    thumbnail_imgs.each_with_index do |img, i|
      src = img["src"]
      assert(src.present?, "Thumbnail #{i + 1} should have src")
      assert(src.start_with?("data:image"),
             "Thumbnail #{i + 1} src should be base64, got: #{src[0..50]}")
    end
  end

  # An image over the upload size limit must block submission with a
  # visible, blocking message naming the file -- never be silently
  # dropped (issue #4872). Stub the limit tiny so a normal test image
  # exceeds it, rather than fabricating a 20+ MB file.
  def test_oversized_image_blocks_submission_with_alert
    setup_image_dirs
    login!(rolf)

    MO.stub(:image_upload_max_size, 1000) do
      visit(new_observation_path)
      click_attach_file("Coprinus_comatus.jpg")
      assert_selector(".carousel-item[data-image-status='upload']", wait: 10)

      assert_no_difference(["Image.count", "Observation.count"]) do
        alert_text = accept_alert do
          within("#observation_form") { click_commit }
        end
        assert_includes(alert_text, "Coprinus_comatus.jpg",
                        "alert must name the over-limit file")
      end

      # Submission was blocked client-side: still on the new-obs form.
      assert_selector("body.observations__new")
    end
  end
end
