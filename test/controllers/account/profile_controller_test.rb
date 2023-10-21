# frozen_string_literal: true

require("test_helper")

# tests of Profile controller
module Account
  class ProfileControllerTest < FunctionalTestCase
    def test_edit
      # First make sure it can serve the form to start with.
      requires_login("edit")

      # Now change everything. (Note this user owns no images, so this tests
      # the bulk copyright_holder updater in the boundary case of no images.)
      params = {
        user: {
          name: "new_name",
          notes: "new_notes",
          place_name: "Burbank, California, USA",
          mailing_address: ""
        }
      }
      patch(:update, params: params)
      assert_flash_text(:runtime_profile_success.t)

      # Make sure changes were made.
      user = rolf.reload
      assert_equal("new_name", user.name)
      assert_equal("new_notes", user.notes)
      assert_equal(locations(:burbank), user.location)
    end

    # Test uploading mugshot for user profile.
    def test_add_mugshot
      # Create image directory and populate with test images.
      setup_image_dirs

      # Open file we want to upload.
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("test/images/sticky.jpg").to_s, "image/jpeg"
      )

      # It should create a new image: this is the current number of images.
      num_images = Image.count

      # Post form.
      params = {
        user: {
          name: rolf.name,
          place_name: "",
          notes: "",
          upload_image: file,
          mailing_address: rolf.mailing_address
        },
        upload: {
          license_id: licenses(:ccnc25).id,
          copyright_holder: "Someone Else",
          copyright_year: "2003"
        }
      }
      File.stub(:rename, false) do
        login("rolf", "testpassword")
        patch(:update, params: params)
      end
      assert_redirected_to(user_path(rolf.id))
      assert_flash_success

      rolf.reload
      assert_equal(num_images + 1, Image.count)
      assert_equal(Image.last.id, rolf.image_id)
      assert_equal("Someone Else", rolf.image.copyright_holder)
      assert_equal(2003, rolf.image.when.year)
      assert_equal(licenses(:ccnc25), rolf.image.license)
    end
  end
end
