# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Images
  class FilenamesControllerTest < FunctionalTestCase
    def test_bulk_original_filename_purge
      imgs = Image.where.not(original_name: "").where(user_id: rolf.id)
      assert(imgs.any?)

      login("rolf")
      put(:update)
      imgs = Image.where.not(original_name: "").where(user_id: rolf.id)
      assert(imgs.empty?)
    end
  end
end
