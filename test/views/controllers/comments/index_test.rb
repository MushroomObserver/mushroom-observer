# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Comments
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @comments = ::Comment.order(:id).limit(3).to_a
    end

    # Parity: the old raw `div.list-group { CommentRow }` and the new
    # `Components::ListGroup::Base { list.item { CommentItem } }` must
    # produce the same DOM. CommentRow itself wraps CommentItem in a
    # `Components::ListGroup::Item`, so both paths delegate to the
    # same component for the `.list-group-item` wrapper.
    def test_list_group_parity_with_legacy_comment_row_render
      old_html = render(LegacyCommentList.new(
                          comments: @comments, user: @user
                        ))
      new_html = render_list_only(objects: @comments)

      assert_html_element_equivalent(
        "<div id='parity'>#{old_html}</div>",
        "<div id='parity'>#{new_html}</div>",
        selector: "#parity",
        label: "comments_index_list_group"
      )
    end

    def test_renders_list_group_with_one_item_per_comment
      html = render_list_only

      assert_html(html, "div.list-group")
      @comments.each do |comment|
        assert_html(html, "##{dom_id(comment)}.list-group-item.comment")
      end
    end

    def test_renders_nothing_when_no_comments
      html = render_list_only(objects: [])

      assert_equal("", html)
    end

    # Legacy list shape — raw div.list-group + CommentRow (which
    # internally delegates to Components::ListGroup::Item). Kept here
    # as the "before" reference for the parity assertion above; not
    # used in production.
    class LegacyCommentList < Components::Base
      include Phlex::Rails::Helpers::DOMID

      prop :comments, _Array(::Comment)
      prop :user, _Nilable(::User), default: nil

      def view_template
        div(class: "list-group") do
          @comments.each do |comment|
            render(CommentRow.new(comment: comment, user: @user,
                                  show_name: true, editable: @user.nil?))
          end
        end
      end
    end

    private

    def render_list_only(objects: @comments)
      return "" unless objects.any?

      render(NewCommentList.new(comments: objects, user: @user))
    end

    # New list shape — Components::ListGroup::Base with list.item +
    # CommentItem. Mirrors what comments/index.rb#render_list now does.
    class NewCommentList < Components::Base
      include Phlex::Rails::Helpers::DOMID

      prop :comments, _Array(::Comment)
      prop :user, _Nilable(::User), default: nil

      def view_template
        render(::Components::ListGroup::Base.new) do |list|
          @comments.each do |comment|
            list.item(class: "comment", id: dom_id(comment)) do
              render(CommentItem.new(comment: comment, user: @user,
                                     show_name: true, editable: @user.nil?))
            end
          end
        end
      end
    end
  end
end
