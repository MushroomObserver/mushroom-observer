# frozen_string_literal: true

# Form for adding or editing project members.
#
# For new members: renders autocompleter to select a user
# For existing members: renders status change buttons
class Components::ProjectMemberForm < Components::ApplicationForm
  def initialize(model, project:, **)
    @project = project
    super(model, id: "project_member_form", **)
  end

  def view_template
    if model.persisted?
      render_update_form
    else
      render_create_form
    end
  end

  private

  def render_create_form
    div(class: "container-text mt-3 pb-2") do
      div(class: "d-flex align-items-end") do
        autocompleter_field(
          :candidate,
          type: :user,
          label: "#{:LOGIN_NAME.t}:",
          inline: true
        )
        submit(:ADD.t, class: "ml-3")
      end
    end
  end

  def render_update_form
    render_status_button(:change_member_status_make_member)
    render_status_button(:change_member_status_remove_member)
    render_status_button(:change_member_status_make_admin)
  end

  def render_status_button(key)
    div(class: "form-group mt-3") do
      submit(key.l, center: true)
      plain(" ")
      trusted_html(:"#{key}_help".t)
    end
  end

  def form_action
    if model.persisted?
      url_for(controller: "projects/members", action: :update,
              project_id: @project.id, candidate: model.user_id,
              only_path: true)
    else
      url_for(controller: "projects/members", action: :create,
              project_id: @project.id, only_path: true)
    end
  end
end
