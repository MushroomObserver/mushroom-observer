# frozen_string_literal: true

require("test_helper")
require("set")

module Names
  class ClassificationControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_get_edit_classification
      # Make sure user has to be logged in.
      get(:edit_classification)
      assert_redirected_to(new_account_login_path)
      login("rolf")

      # Make sure missing and bogus ids do not crash it.
      get(:edit_classification)
      assert_response(:redirect)
      get(:edit_classification, params: { id: "bogus" })
      assert_response(:redirect)

      # Make sure form initialized correctly.
      name = names(:boletus_edulis)
      get(:edit_classification, params: { id: name.id })
      assert_response(:success)
      assert_template(:edit_classification)
      assert_textarea_value(:classification, "")

      name = names(:agaricus_campestris)
      get(:edit_classification, params: { id: name.id })
      assert_response(:success)
      assert_template(:edit_classification)
      assert_textarea_value(:classification, name.classification)
    end

    def test_post_edit_classification
      # Make sure user has to be logged in.
      post(:edit_classification)
      assert_redirected_to(new_account_login_path)
      login("rolf")

      # Make sure bogus requests don't crash.
      post(:edit_classification)
      assert_flash_error
      assert_response(:redirect)
      post(:edit_classification, params: { id: "bogus" })
      assert_flash_error
      assert_response(:redirect)

      # Make sure it is validating the classification.
      name = names(:agaricus_campestris)
      post(:edit_classification,
           params: { id: name.id, classification: "bogus" })
      assert_flash_error
      assert_response(:success)
      assert_template(:edit_classification)
      assert_textarea_value(:classification, "bogus")

      # Make sure we can do simple case.
      name = names(:agaricales)
      new_str = "Kingdom: _Fungi_"
      post(:edit_classification,
           params: { id: name.id, classification: new_str })
      assert_no_flash
      assert_redirected_to(name.show_link_args)
      assert_equal(new_str, name.reload.classification)

      # Make sure we can do complex case.
      name = names(:agaricus_campestris)
      new_str = "Kingdom: _Fungi_\r\nPhylum: _Ascomycota_"
      post(:edit_classification,
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
