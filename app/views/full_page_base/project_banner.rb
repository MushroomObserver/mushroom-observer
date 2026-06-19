# frozen_string_literal: true

# Project-banner setter mixed into `Views::FullPageBase`.
#
# Project-scoped show / index pages (any view that calls
# `add_project_banner(@project)`) get a project-branded banner across
# the top of the page body, with tabs that navigate within the
# project's resources (observations, names, locations, etc.).
#
# `active_project_tab` is a controller helper — `ApplicationController`
# defines the default and `Projects::MembersController` /
# `Projects::AliasesController` override per-page. Keeping the
# resolution on the controller side means project sub-controllers can
# keep overriding it without us having to thread the override through
# every action view.
module Views::FullPageBase::ProjectBanner
  def add_project_banner(project)
    content_for(:project_banner) do
      capture do
        render(::Views::Controllers::Projects::Banner.new(
                 project: project,
                 user: current_user,
                 current_tab: controller.active_project_tab
               ))
      end
    end
  end
end
