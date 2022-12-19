# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Account::Images
  class FilenamesControllerTest < FunctionalTestCase
    def test_bulk_original_filename_purge
      imgs = Image.where("original_name != '' AND user_id = #{rolf.id}")
      assert(imgs.any?)

      login("rolf")
      get(:bulk_filename_purge)
      imgs = Image.where("original_name != '' AND user_id = #{rolf.id}")
      assert(imgs.empty?)
    end
  end
end
