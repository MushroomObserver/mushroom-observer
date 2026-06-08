# frozen_string_literal: true

# New-comment page: the comment form followed by the
# `CommentsForObject` panel for the target. When the target is an
# Observation, a sidebar Images panel sits next to the form so the
# commenter can reference the photos while typing.
#
# Replaces `app/views/controllers/comments/new.html.erb` (and its
# `_object.html.erb` partial render — inlined here).
module Views::Controllers::Comments
  class New < Views::Base
    prop :comment, ::Comment
    prop :target, ::AbstractModel
    prop :user, _Nilable(::User), default: nil

    def view_template
      container_class(:full)
      add_page_title(:comment_add_title.t(
                       name: @target.unique_format_name
                     ))
      add_context_nav(::Tab::Comment::FormNew.new(target: @target))

      div(class: "row") do
        render_form_column
        render_images_column if @target.is_a?(::Observation)
      end
    end

    private

    def render_form_column
      div(class: "col-xs-12 col-sm-8") do
        comment { "[form:comment]" }
        render(Form.new(@comment, local: true))
        comment { "[eoform:comment]" }
        render_object_panel
      end
    end

    def render_object_panel
      render(CommentsForObject.new(
               object: @target,
               comments: ::Comment.where(target: @target).to_a,
               user: @user, editable: false, limit: 10
             ))
    end

    def render_images_column
      div(class: "col-xs-12 col-sm-4") do
        render(::Views::Controllers::Observations::Show::ImagesPanel.new(
                 obs: @target, images: @target.images_sorted, user: @user
               ))
      end
    end
  end
end
