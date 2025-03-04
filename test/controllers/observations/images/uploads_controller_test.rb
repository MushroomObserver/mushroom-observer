# frozen_string_literal: true

module Observations::Images
  class UploadsControllerTest < FunctionalTestCase
    def test_upload_image
      # Arrange
      setup_image_dirs
      login("dick")
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("test/images/Coprinus_comatus.jpg").to_s, "image/jpeg"
      )
      copyright_holder = "Douglas Smith"
      notes = "Some notes."

      params = {
        image: {
          when: { "3i" => "27", "2i" => "11", "1i" => "2014" },
          copyright_holder: copyright_holder,
          notes: notes,
          upload: file
        }
      }

      # Act
      File.stub(:rename, false) do
        post(:create, params: params)
      end
      @json_response = JSON.parse(@response.body)

      # Assert
      assert_response(:success)
      assert_not_equal(0, @json_response["id"])
      assert_equal(copyright_holder, @json_response["copyright_holder"])
      assert_equal(notes, @json_response["notes"])
      assert_equal("2014-11-27", @json_response["when"])
    end
  end
end
