# frozen_string_literal: true

# New-comment page: the comment form followed by the
# `CommentsForObject` panel for the target. When the target is an
# Observation, a sidebar Images panel sits next to the form so the
# commenter can reference the photos while typing.
module Views::Controllers::Comments
  class New < Views::FullPageBase
    prop :comment, ::Comment
    prop :target, ::AbstractModel
    prop :user, _Nilable(::User), default: nil
    # Comments on `target` pre-loaded by the controller, fed into
    # `CommentsForObject` below.
    prop :comments, _Array(::Comment)

    def view_template
      container_class(:full)
      add_page_title(:comment_add_title.t(
                       name: @target.unique_format_name
                     ))
      add_context_nav(::Tab::Comment::FormNew.new(target: @target))

      Row do
        render_form_column
        render_images_column if @target.is_a?(::Observation)
      end
    end

    private

    def render_form_column
      Column(xs: 12, sm: 8) do
        comment { "[form:comment]" }
        render(Form.new(@comment, local: true))
        comment { "[eoform:comment]" }
        render_object_panel
      end
    end

    def render_object_panel
      render(CommentsForObject.new(
               object: @target,
               comments: @comments.to_a,
               user: @user, editable: false, limit: 10
             ))
    end

    def render_images_column
      Column(xs: 12, sm: 4) do
        render(::Views::Controllers::Observations::Show::ImagesPanel.new(
                 obs: @target, images: @target.images_sorted, user: @user
               ))
      end
    end
  end
end
