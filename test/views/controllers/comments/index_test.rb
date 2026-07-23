# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Comments
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @comments = ::Comment.order(:id).limit(3).to_a
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

    private

    def render_list_only(objects: @comments)
      return "" unless objects.any?

      render(NewCommentList.new(comments: objects, user: @user))
    end

    # Components::ListGroup with list.item + CommentItem. Mirrors what
    # comments/index.rb#render_list does.
    class NewCommentList < Components::Base
      include Phlex::Rails::Helpers::DOMID

      prop :comments, _Array(::Comment)
      prop :user, _Nilable(::User), default: nil

      def view_template
        ListGroup do |list|
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
