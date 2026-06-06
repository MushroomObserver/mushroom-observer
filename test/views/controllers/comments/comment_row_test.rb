# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Comments
  class CommentRowTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @comment = comments(:minimal_unknown_obs_comment_1)
      controller.instance_variable_set(:@user, @user)
    end

    def test_renders_list_group_item_wrapper_with_comment_class_and_dom_id
      # The wrapper id/class are the contract the Comment model's
      # `broadcast_update_to(target: dom_id(comment))` and
      # `broadcast_remove_to` callbacks target.
      html = render_row

      assert_html(html, "div.list-group-item.comment##{dom_id(@comment)}")
    end

    def test_wraps_a_comment_item
      # The inner content is a CommentItem — its row + comment-info
      # markup must show up INSIDE the wrapper, not as a sibling.
      html = render_row

      assert_html(html, "div##{dom_id(@comment)} > div.row")
      assert_html(html, "div##{dom_id(@comment)} .comment-summary",
                  text: @comment.summary)
    end

    def test_propagates_editable_flag_to_comment_item
      # editable=true is the broadcast-prepend case (after_create_commit
      # uses CommentRow with editable: true) — the inner CommentItem
      # gets the real UserLink + mod-links treatment.
      html = render_row(editable: true)

      assert_html(html, "a.user_link_#{@comment.user.id}")
      assert_html(html, "[data-user-specific='#{@comment.user.id}']")
    end

    def test_propagates_show_name_flag_to_comment_item
      # show_name=true is the comments-index shape — the target
      # heading flows through to the inner CommentItem.
      html = render_row(show_name: true)

      assert_html(html, "h4 a[href*='#{@comment.target.id}']")
    end

    private

    def dom_id(record)
      ::ActionView::RecordIdentifier.dom_id(record)
    end

    def render_row(comment: @comment, user: @user, editable: false,
                   show_name: false)
      render(CommentRow.new(comment: comment, user: user,
                            editable: editable, show_name: show_name))
    end
  end
end
