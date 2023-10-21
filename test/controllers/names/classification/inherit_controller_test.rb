# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Classification
  class InheritControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def create_name(name)
      parse = Name.parse_name(name)
      Name.new_name(parse.params)
    end

    def test_get_inherit_classification
      name = names(:boletus)

      # Make sure user has to be logged in.
      get(:new, params: { id: name.id })
      assert_redirected_to(new_account_login_path)
      login("rolf")

      # Make sure it doesn't crash if id is missing.
      # get(:new)
      # assert_flash_error
      # assert_response(:redirect)

      # Make sure it doesn't crash if id is bogus.
      get(:new, params: { id: "bogus" })
      assert_flash_error
      assert_response(:redirect)

      # Make sure it doesn't crash if id is bogus.
      get(:new, params: { id: name.id })
      assert_no_flash
      assert_response(:success)
      assert_template("names/classification/inherit/new")
    end

    def test_post_inherit_classification
      name = names(:boletus)

      # Make sure user has to be logged in.
      post(:create, params: { id: name.id, parent: "Agaricales" })
      assert_redirected_to(new_account_login_path)
      login("rolf")

      # Make sure it doesn't crash if id is missing.
      # post(:create, params: { parent: "Agaricales" })
      # assert_flash_error
      # assert_response(:redirect)

      # Make sure it doesn't crash if id is bogus.
      post(:create, params: { id: "bogus", parent: "Agaricales" })
      assert_flash_error
      assert_response(:redirect)

      # Test reload if parent field missing.
      post(:create, params: { id: name.id, parent: "" })
      assert_flash_error
      assert_response(:success)
      assert_template("names/classification/inherit/new")

      # Test reload if parent field has no match and no alternate spellings.
      post(:create,
           params: { id: name.id, parent: "cakjdncaksdbcsdkn" })
      assert_flash_error
      assert_response(:success)
      assert_template("names/classification/inherit/new")
      assert_input_value("parent", "cakjdncaksdbcsdkn")

      # Test reload if parent field misspelled.
      post(:create,
           params: { id: name.id, parent: "Agariclaes" })
      assert_no_flash
      assert_response(:success)
      assert_template("names/classification/inherit/new")
      assert_not_blank(assigns(:message))
      assert_not_empty(assigns(:options))
      assert_select("label", text: "Agaricales")
      assert_input_value("parent", "Agariclaes")

      # Test ambiguity: three names all accepted and with classifications.
      parent1 = names(:agaricaceae)
      parent1.change_author("Ach.")
      parent1.save
      parent2 = create_name("Agaricaceae Bagl.")
      parent2.classification = "Domain: _Eukarya_"
      parent2.save
      parent3 = create_name("Agaricaceae Clauzade")
      parent3.classification = "Domain: _Eukarya_"
      parent3.save
      post(:create,
           params: { id: name.id, parent: "Agaricaceae" })
      assert_no_flash
      assert_response(:success)
      assert_template("names/classification/inherit/new")
      assert_not_blank(assigns(:message))
      assert_not_empty(assigns(:options))
      assert_select("input[type=radio][value='#{parent1.id}']", count: 1)
      assert_select("input[type=radio][value='#{parent2.id}']", count: 1)
      assert_select("input[type=radio][value='#{parent3.id}']", count: 1)
      assert_input_value("parent", "Agaricaceae")

      # Have it select a bogus name (rank wrong in this case).
      post(:create,
           params: { id: name.id,
                     parent: "Agaricaceae",
                     options: names(:coprinus_comatus).id })
      assert_flash_error
      assert_response(:success)
      assert_template("names/classification/inherit/new")

      # Make it less ambiguous, so it will select the original Agaricaceae.
      Name.update(parent2.id, classification: "")
      Name.update(parent3.id, deprecated: true)
      assert_blank(name.reload.classification)
      post(:create,
           params: { id: name.id, parent: "Agaricaceae" })
      assert_no_flash
      assert_name_arrays_equal([], assigns(:options))
      assert_blank(assigns(:message))
      assert_redirected_to(name.show_link_args)
      new_str = "#{parent1.classification}\r\nFamily: _Agaricaceae_\r\n"
      assert_equal(new_str, name.reload.classification)
      assert_equal(new_str, names(:boletus_edulis).classification)
      assert_equal(new_str, observations(:boletus_edulis_obs).classification)
    end
  end
end
