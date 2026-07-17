# frozen_string_literal: true

# Turbo Stream row updates for the `create`/`update`/`destroy` actions.
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
# `create`'s row insert uses the custom `prepend_once` action (see
# `config/initializers/turbo_stream_actions.rb`), not the built-in
# `prepend` -- unlike `update`/`remove`, a plain `prepend` isn't
# idempotent, and `after_create_commit` dispatches its own broadcast
# before this response is even built, so the two would routinely race
# and insert the row twice. `prepend_once` is a client-side no-op if
# the row's id is already in the DOM, so whichever of the two arrives
# second doesn't duplicate it.
module CommentsController::RowStreams
  private

  def prepend_comment_row
    turbo_stream.prepend_once(
      "comments",
      ::Views::Controllers::Comments::CommentRow.new(
        comment: @comment, user: @user, editable: @user.present?
      )
    )
  end

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
