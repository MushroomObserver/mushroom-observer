# frozen_string_literal: true

require("test_helper")

module Tab::Comment
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @comment = comments(:fungi_comment)
      @target = @comment.target
    end

    def test_new
      tab = Tab::Comment::New.new(object: @target)

      assert_equal(:show_comments_add_comment.l, tab.title)
      assert_equal(
        routes.new_comment_path(target: @target.id, type: @target.class.name),
        tab.path
      )
      assert_nil(tab.html_options[:icon])
      assert_equal(@target, tab.model)
    end

    def test_edit
      tab = Tab::Comment::Edit.new(comment: @comment)

      assert_equal(:comment_show_edit.t, tab.title)
      assert_equal(routes.edit_comment_path(@comment.id), tab.path)
      assert_equal(:edit, tab.html_options[:icon])
      assert_equal(@comment, tab.model)
    end

    def test_destroy
      tab = Tab::Comment::Destroy.new(comment: @comment)

      assert_equal(:comment_show_destroy.t, tab.title)
      assert_equal(@comment, tab.path)
      assert_equal(:destroy, tab.html_options[:button])
      assert_equal(@comment, tab.model)
    end
  end
end
