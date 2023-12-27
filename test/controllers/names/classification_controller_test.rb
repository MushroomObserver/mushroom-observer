# frozen_string_literal: true

require("test_helper")

module Names
  class ClassificationControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_get_edit_classification
      name = names(:boletus_edulis)
      # Make sure user has to be logged in.
      get(:edit, params: { id: name.id })
      assert_redirected_to(new_account_login_path)
      login("rolf")

      # Make sure (missing and) bogus ids do not crash it.
      # get(:edit)
      # assert_response(:redirect)
      get(:edit, params: { id: "bogus" })
      assert_response(:redirect)

      # Make sure form initialized correctly.
      get(:edit, params: { id: name.id })
      assert_response(:success)
      assert_template("names/classification/edit")
      assert_textarea_value(:classification, "")
      assert_select("form[action = '#{name_classification_path(name)}']") do
        assert_select("input[value = 'put']", { count: 1 },
                      "Form should submit via PUT")
      end

      name = names(:agaricus_campestris)
      get(:edit, params: { id: name.id })
      assert_response(:success)
      assert_template("names/classification/edit")
      assert_textarea_value(:classification, name.classification)
    end

    def test_update_classification
      name = names(:agaricus_campestris)

      # Make sure user has to be logged in.
      put(:update, params: { id: name.id })
      assert_redirected_to(new_account_login_path)
      login("rolf")

      # Make sure bogus requests don't crash.
      # put(:update)
      # assert_flash_error
      # assert_response(:redirect)
      put(:update, params: { id: "bogus" })
      assert_flash_error
      assert_response(:redirect)

      # Make sure it is validating the classification.
      put(:update,
          params: { id: name.id, classification: "bogus" })
      assert_flash_error
      assert_response(:success)
      assert_template("names/classification/edit")
      assert_textarea_value(:classification, "bogus")

      # Make sure we can do simple case.
      name = names(:agaricales)
      new_str = "Kingdom: _Fungi_"
      put(:update,
          params: { id: name.id, classification: new_str })
      assert_no_flash
      assert_redirected_to(name.show_link_args)
      assert_equal(new_str, name.reload.classification)

      # Make sure we can do complex case.
      name = names(:agaricus_campestris)
      new_str = "Kingdom: _Fungi_\r\nPhylum: _Ascomycota_"
      put(:update,
          params: { id: name.id, classification: new_str })
      assert_no_flash
      assert_redirected_to(name.show_link_args)
      assert_equal(new_str, name.reload.classification)
      assert_equal(new_str, names(:agaricus).classification)
      assert_equal(new_str,
                   names(:agaricus_campestras).description.classification)
      assert_equal(new_str,
                   observations(:agaricus_campestras_obs).classification)
    end
  end
end
