# frozen_string_literal: true

module Views::Controllers::Images
  # Result page after a `test_add_image` upload completes. Converted
  # from `images/test_upload_speed.html.erb`.
  class TestUploadSpeed < Views::Base
    def view_template
      p { plain("Test complete.") }
    end
  end
end
