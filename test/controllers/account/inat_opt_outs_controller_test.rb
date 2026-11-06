# frozen_string_literal: true

require("test_helper")

module Account
  class InatOptOutsControllerTest < FunctionalTestCase
    def test_update_turns_the_opt_out_on_and_off
      rolf = users(:rolf)
      login("rolf")

      patch(:update, params: { user: { inat_import_opt_out: "1" } })
      assert(rolf.reload.inat_import_opt_out)
      assert_redirected_to(edit_account_profile_path)
      assert_flash_success

      patch(:update, params: { user: { inat_import_opt_out: "0" } })
      assert_not(rolf.reload.inat_import_opt_out)
    end
  end
end
