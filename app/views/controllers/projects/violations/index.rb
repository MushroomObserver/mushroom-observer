# frozen_string_literal: true

# Action template for the Project Violations index. Replaces
# `app/views/controllers/projects/violations/index.html.erb`.
#
# Renders the project banner + the violations form.
#
# `Projects::ViolationsController#index` renders this class
# directly with explicit props.
module Views::Controllers::Projects::Violations
  class Index < Views::FullPageBase
    prop :project, ::Project
    prop :violations, _Array(::Project::Violation)
    # Non-nilable: this view forwards `user` to `Violations::Form`,
    # whose `prop :user` is non-nilable, and the controller's
    # `login_required` guarantees `@user` is present.
    prop :user, ::User

    def view_template
      add_project_banner(@project)
      container_class(:wide)

      render(Views::Controllers::Projects::Violations::Form.new(
               project: @project, violations: @violations, user: @user
             ))
    end
  end
end
