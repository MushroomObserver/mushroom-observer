# frozen_string_literal: true

require("test_helper")

module Names
  class ClassificationControllerTest < FunctionalTestCase
    def test_get_edit_classification
      name = names(:boletus_edulis)
      # Make sure user has to be logged in.
      get(:edit, params: { id: name.id })
      assert_redirected_to(new_account_login_path)
      login("rolf")

      # Make sure form initialized correctly -- no classification yet,
      # every rank field blank.
      get(:edit, params: { id: name.id })
      assert_response(:success)
      assert_input_value("name_classification_rank_kingdom", nil)
      assert_select("form[action = '#{classification_of_name_path(name)}']") do
        assert_select("input[value = 'patch']", { count: 1 },
                      "Form should submit via PATCH")
      end

      name = names(:agaricus_campestris)
      get(:edit, params: { id: name.id })
      assert_response(:success)
      assert_input_value("name_classification_rank_kingdom", "Fungi")
    end

    def test_update_classification
      name = names(:agaricus_campestris)

      # Make sure user has to be logged in.
      put(:update, params: { id: name.id })
      assert_redirected_to(new_account_login_path)
      login("rolf")

      # Make sure it is validating the classification -- rank
      # guessing isn't applied to Kingdom/Domain, so the mismatch has
      # to be on a rank between them and Genus.
      put(:update,
          params: { id: name.id,
                    name_classification: { rank_phylum: "bogus" } })
      assert_flash_error
      assert_unprocessable
      assert_select("form[data-turbo='true']")
      assert_input_value("name_classification_rank_phylum", "bogus")

      # Make sure we can do the simple case.
      name = names(:agaricales)
      put(:update,
          params: { id: name.id,
                    name_classification: { rank_kingdom: "Fungi" } })
      assert_no_flash
      assert_redirected_to(name.show_link_args)
      assert_equal("Kingdom: _Fungi_", name.reload.classification)

      # Make sure we can do the complex case.
      name = names(:agaricus_campestris)
      put(:update,
          params: { id: name.id,
                    name_classification: { rank_kingdom: "Fungi",
                                           rank_phylum: "Ascomycota" } })
      assert_no_flash
      assert_redirected_to(name.show_link_args)
      expect = "Kingdom: _Fungi_\r\nPhylum: _Ascomycota_"
      assert_equal(expect, name.reload.classification)
      assert_equal(expect, names(:agaricus).classification)
      # Description and Observation no longer carry classification
      # caches — both columns dropped in discussion #4163.
    end
  end
end
