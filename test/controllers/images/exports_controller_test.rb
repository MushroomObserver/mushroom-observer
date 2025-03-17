# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Images
  class ExportsControllerTest < FunctionalTestCase
    def test_export_image
      img = images(:in_situ_image)
      assert_true(img.ok_for_export) # (default)

      put(:update, params: { id: img.id, value: 0 })
      assert_redirected_to(new_account_login_path)

      login("rolf")
      put(:update, params: { id: img.id, value: 0 })
      assert_false(img.reload.ok_for_export)

      put(:update, params: { id: img.id, value: 1 })
      assert_true(img.reload.ok_for_export)

      # put(:update, params: { id: 999, value: "1" })
      # put(:update, params: { id: img.id, value: "2" })
    end
  end
end
