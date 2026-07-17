# frozen_string_literal: true

# Turbo Stream row updates for the `update`/`destroy` actions.
#
# The synchronous turbo_stream response has to apply the row change
# itself -- the `Comment` model's own `after_*_commit` broadcast
# callbacks (see `comment.rb`) are async and aren't guaranteed to
# reach the submitter's own tab before (or ever, if the connection
# drops) the modal-closing response arrives. Relying on the broadcast
# alone left the modal closing with the comment list unchanged (#4833).
#
# The model callbacks stay in place for cross-tab / cross-user sync;
# these methods only cover the acting user's own request.
#
# `create` deliberately has no synchronous counterpart here. Unlike
# `update`/`remove`, `prepend` isn't idempotent: `after_create_commit`
# fires (and dispatches its broadcast) before the controller even
# builds this response, so a synchronous prepend would very often
# race a second, duplicate prepend of the same row once the broadcast
# lands. `create` isn't reported broken (#4833 is update/destroy
# only), so it's left to the model's broadcast alone.
module CommentsController::RowStreams
  private

  def update_comment_row
    turbo_stream.update(
      ::ActionView::RecordIdentifier.dom_id(@comment),
      ::Views::Controllers::Comments::CommentItem.new(
        comment: @comment, user: @user, editable: @user.present?
      )
    )
  end

  def remove_comment_row
    turbo_stream.remove(::ActionView::RecordIdentifier.dom_id(@comment))
  end
end
