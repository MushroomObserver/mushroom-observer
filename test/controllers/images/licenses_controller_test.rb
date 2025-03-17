# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Images
  class LicensesControllerTest < FunctionalTestCase
    def test_edit_license_page_access
      requires_login(:edit)

      assert_form_action(action: :update)
      assert_select(
        "select[name='updates[1][new_id]']", { count: 1 },
        "Form should have numerical selectors nested under `updates`"
      )
    end

    def test_update_licenses
      example_image    = images(:agaricus_campestris_image)
      user_id          = example_image.user_id
      copyright_holder = example_image.copyright_holder
      old_license      = example_image.license

      target_license = example_image.license
      new_license    = licenses(:ccwiki30)
      assert_not_equal(target_license, new_license)
      assert_equal(0, example_image.copyright_changes.length)

      target_count = Image.where(user_id: user_id,
                                 license_id: target_license.id,
                                 copyright_holder: copyright_holder).length
      new_count = Image.where(user_id: user_id,
                              license_id: new_license.id,
                              copyright_holder: copyright_holder).length
      assert(target_count.positive?)
      assert(new_count.zero?)

      params = {
        updates: {
          "1" => {
            old_id: target_license.id.to_s,
            new_id: new_license.id.to_s,
            old_holder: copyright_holder,
            new_holder: copyright_holder
          }
        }
      }
      put_requires_login(:update, params)
      # assert_redirected_to(images_edit_licenses_path)
      assert_template("images/licenses/edit")
      assert_equal(10, rolf.reload.contribution)

      target_count_after = Image.
                           where(user_id: user_id,
                                 license_id: target_license.id,
                                 copyright_holder: copyright_holder).
                           length
      new_count_after = Image.where(user_id: user_id,
                                    license_id: new_license.id,
                                    copyright_holder: copyright_holder).length
      assert(target_count_after < target_count)
      assert(new_count_after > new_count)
      assert_equal(target_count_after + new_count_after,
                   target_count + new_count)
      example_image.reload
      assert_equal(new_license.id, example_image.license_id)
      assert_equal(copyright_holder, example_image.copyright_holder)
      assert_equal(1, example_image.copyright_changes.length,
                   "Wrong number of copyright changes")
      assert_equal(old_license.id,
                   example_image.copyright_changes.last.license_id)

      # This empty string caused it to crash in the wild.
      example_image.reload
      example_image.copyright_holder = ""
      example_image.save
      # (note: the above creates a new entry in copyright_changes!!)
      params = {
        updates: {
          "1" => {
            old_id: new_license.id.to_s,
            new_id: new_license.id.to_s,
            old_holder: "",
            new_holder: "A. H. Smith"
          }
        }
      }
      put_requires_login(:update, params)
      assert_template("images/licenses/edit")
      example_image.reload
      assert_equal("A. H. Smith", example_image.copyright_holder,
                   "Name of new copyright holder is incorrect")
      assert_equal(3, example_image.copyright_changes.length)
      assert_equal(new_license.id,
                   example_image.copyright_changes.last.license_id)
      assert_equal("", example_image.copyright_changes.last.name,
                   "Name of prior copyright holder is incorrect")
    end
  end
end
