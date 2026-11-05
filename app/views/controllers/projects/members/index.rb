# frozen_string_literal: true

module Views::Controllers::Projects::Members
  # Phlex view for the project members index page.
  class Index < Views::FullPageBase
    prop :project, ::Project
    prop :users, _Array(::User)
    prop :pagination, ::PaginationData
    prop :user, ::User

    def view_template
      add_project_banner(@project)
      container_class(:wide)
      add_pagination(@pagination)

      render(AddForm.new(project: @project))
      PaginatedResults do
        render(Tables.new(project: @project, users: @users, user: @user))
      end
    end
  end
end
