# frozen_string_literal: true

require("test_helper")

module Names::Lifeforms
  class PropagateControllerTest < FunctionalTestCase
    include ObjectLinkHelper
    def test_propagate_lifeform
      name = names(:lecanorales)
      children = name.all_children
      Name.update(name.id, lifeform: " lichen ")

      # Prove that getting to the form requires a login, and that it starts off
      # with all boxes unchecked.
      requires_login(:edit, id: name.id)
      assert_template("names/lifeforms/propagate/edit")
      Name.all_lifeforms.each do |word|
        if word == "lichen"
          assert_input_value("add_#{word}", "")
        else
          assert_input_value("remove_#{word}", "")
        end
      end

      # Make sure we can add "lichen" to all children.
      put(:update, params: { id: name.id, add_lichen: "1" })
      assert_redirected_to(name.show_link_args)
      children.each do |child|
        assert(child.reload.lifeform.include?(" lichen "),
               "Child, #{child.search_name}, is missing 'lichen'.")
      end

      # Make sure we can remove "lichen" from all children, too.
      put(:update, params: { id: name.id, remove_lichen: "1" })
      assert_redirected_to(name.show_link_args)
      children.each do |child|
        assert_not(child.reload.lifeform.include?(" lichen "),
                   "Child, #{child.search_name}, still has 'lichen'.")
      end
    end
  end
end
