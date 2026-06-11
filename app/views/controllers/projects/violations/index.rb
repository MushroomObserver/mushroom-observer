# frozen_string_literal: true

# Action template for the Project Violations index. Replaces
# `app/views/controllers/projects/violations/index.html.erb`.
#
# Renders the project banner + the violations form.
#
# `Projects::ViolationsController#index` renders this class
# directly with explicit props.
module Views::Controllers::Projects::Violations
  class Index < Views::Base
    prop :project, ::Project
    prop :violations, _Array(::Project::Violation)
    prop :user, _Nilable(::User), default: nil

    def view_template
      add_project_banner(@project)
      container_class(:wide)

      render(Views::Controllers::Projects::Violations::Form.new(
               project: @project, violations: @violations, user: @user
             ))
    end
  end
end
