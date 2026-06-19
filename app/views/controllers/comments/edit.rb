# frozen_string_literal: true

# Edit-comment page: the comment form followed by the
# `CommentsForObject` panel for the target (so the editor can see
# existing comments in context).
module Views::Controllers::Comments
  class Edit < Views::FullPageBase
    prop :comment, ::Comment
    prop :target, ::AbstractModel
    prop :user, _Nilable(::User), default: nil
    # Comments on `target` pre-loaded by the controller, fed into
    # `CommentsForObject` below.
    prop :comments, _Array(::Comment)

    def view_template
      add_page_title(:comment_edit_title.t(
                       name: @target.unique_format_name
                     ))
      add_context_nav(::Tab::Comment::FormEdit.new(comment: @comment))

      # `[form:comment]…[eoform:comment]` HTML-comment markers.
      # No in-tree caller; kept in case external scrapers /
      # integration tools look for them.
      comment { "[form:comment]" }
      render(Form.new(@comment, local: true))
      comment { "[eoform:comment]" }

      render_object_panel
    end

    private

    # Mirrors `_object.rb`: render the comments-for-object
    # panel for the target.
    def render_object_panel
      render(CommentsForObject.new(
               object: @target,
               comments: @comments.to_a,
               user: @user, editable: false, limit: 10
             ))
    end
  end
end
