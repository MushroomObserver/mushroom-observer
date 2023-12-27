# frozen_string_literal: true

require("test_helper")

module Names
  class LifeformsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_edit_lifeform
      # Prove that anyone logged in can edit lifeform, and that the form starts
      # off with the correct current state.
      name = names(:peltigera)
      assert_equal(" lichen ", name.lifeform)
      requires_login(:edit, id: name.id)
      assert_template("names/lifeforms/edit")
      Name.all_lifeforms.each do |word|
        assert_input_value("lifeform_#{word}", word == "lichen" ? "1" : "")
      end

      # Make sure user can both add and remove lifeform categories.
      params = { id: name.id }
      Name.all_lifeforms.each do |word|
        params["lifeform_#{word}"] = (word == "lichenicolous" ? "1" : "")
      end
      put(:update, params: params)
      assert_equal(" lichenicolous ", name.reload.lifeform)
    end
  end
end
