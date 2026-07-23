# frozen_string_literal: true

# Rendering/identifying the create/edit modal form.
module CommentsController::ModalForm
  private

  # The identifier needs to be more specific for an edit form, because
  # we give users the option to edit any number of their own comments on a
  # show page. "comment" disambiguates :new, because :edit always has id
  def render_modal_comment_form
    render(Components::Modal.new(
             type: :turbo_form, identifier: modal_identifier,
             title: modal_title,
             user: @user, model: @comment
           ), layout: false)
  end

  def reload_modal_form
    render_modal_form_reload(identifier: modal_identifier,
                             form_locals: { model: @comment })
  end

  def modal_identifier
    case action_name
    when "new", "create"
      "comment"
    when "edit", "update"
      "comment_#{@comment.id}"
    end
  end

  def modal_title
    case action_name
    when "new", "create"
      :comment_add_title.t(name: viewer_aware_unique_format_name(@target))
    when "edit", "update"
      :comment_edit_title.t(name: viewer_aware_unique_format_name(@target))
    end
  end
end
