# frozen_string_literal: true

require("test_helper")

module Tab::Comment
  class CollectionsTest < UnitTestCase
    def setup
      @comment = comments(:fungi_comment)
      @target = @comment.target
    end

    def test_form_new
      tabs = Tab::Comment::FormNew.new(target: @target).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_form_edit
      tabs = Tab::Comment::FormEdit.new(comment: @comment).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_show_actions_no_permission
      tabs = Tab::Comment::ShowActions.new(
        comment: @comment, target: @target
      ).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    def test_show_actions_with_permission
      tabs = Tab::Comment::ShowActions.new(
        comment: @comment, target: @target, permission: true
      ).to_a

      assert_equal(
        [Tab::Object::Return, Tab::Comment::Edit, Tab::Comment::Destroy],
        tabs.map(&:class)
      )
    end
  end
end
