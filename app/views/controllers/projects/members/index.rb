# frozen_string_literal: true

module Views::Controllers::Projects::Members
  # Phlex view for the project members index page.
  class Index < Views::FullPageBase
    prop :project, ::Project
    prop :users, _Array(::User)
    prop :user, ::User

    def view_template
      add_project_banner(@project)
      container_class(:wide)

      render(AddForm.new(project: @project))
      render(Tables.new(project: @project, users: @users, user: @user))
    end
  end
end
