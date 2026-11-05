# frozen_string_literal: true

# Status-change form for an existing project member. Rendered by
# `Projects::MembersController#edit`. Adding a new member is a
# separate widget now -- see `AddForm`.
module Views::Controllers::Projects::Members
  class Form < ::Components::ApplicationForm
    prop :project, ::Project

    def view_template
      render_status_button(:change_member_status_make_member)
      render_status_button(:change_member_status_remove_member)
      render_status_button(:change_member_status_make_admin)
    end

    private

    def render_status_button(key)
      div(class: "form-group mt-3") do
        submit(key.l, center: true)
        whitespace
        trusted_html(:"#{key}_help".t)
      end
    end

    def form_action
      url_for(controller: "projects/members", action: :update,
              project_id: @project.id, candidate: model.user_id,
              only_path: true)
    end
  end
end
