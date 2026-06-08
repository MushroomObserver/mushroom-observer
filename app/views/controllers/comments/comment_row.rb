# frozen_string_literal: true

# Full `<div class="list-group-item comment" id="comment_<id>">` row
# wrapping a `CommentItem`. Two consumers:
#
# - The `Comment` model's `after_create_commit` Turbo Stream
#   broadcast — prepending into the comments list group needs the
#   wrapper element with the right id and class so subsequent
#   `broadcast_update_to(target: "comment_<id>")` calls can find
#   the row in place.
# - The site-wide `comments/index.html.erb` listing — each row
#   stands on its own (no surrounding `CommentsForObject` panel),
#   so the wrapper has to live with the inner content.
#
# Inside the `CommentsForObject` panel, this composition is split:
# `Components::ListGroup#item` provides the wrapper (so the
# none-yet placeholder lives in the same list) and `CommentItem`
# is rendered directly inside the block.
module Views::Controllers::Comments
  class CommentRow < Views::Base
    include Phlex::Rails::Helpers::DOMID

    prop :comment, ::Comment
    prop :user, _Nilable(::User), default: nil
    prop :editable, _Boolean, default: false
    prop :show_name, _Boolean, default: false

    def view_template
      render(Components::ListGroupItem.new(
               class: "comment", id: dom_id(@comment)
             )) do
        render(CommentItem.new(comment: @comment, user: @user,
                               editable: @editable,
                               show_name: @show_name))
      end
    end
  end
end
