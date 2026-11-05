# frozen_string_literal: true

# Project-banner setter mixed into `Views::FullPageBase`.
#
# Project-scoped show / index pages (any view that calls
# `add_project_banner(@project)`) get a project-branded banner across
# the top of the page body, with tabs that navigate within the
# project's resources (observations, names, locations, etc.).
#
# `active_project_tab` is a controller helper -- `ApplicationController`
# defines the default (the demodulized controller_name), and a
# sub-controller may still override it for a page `ProjectNavs` can't
# place from controller_path alone. Pages covered by
# `ProjectNavs::ADMIN_SUBTAB_CONTROLLERS` /
# `::OBSERVATION_SUBTAB_CONTROLLERS` don't need an override --
# `ProjectNavs` derives "admin"/"observations" for those itself and
# ignores whatever this returns.
module Views::FullPageBase::ProjectBanner
  def add_project_banner(project)
    content_for(:project_banner) do
      capture do
        render(::Views::Controllers::Projects::Banner.new(project: project))
        next unless current_user

        render(::Views::Controllers::Projects::ProjectNavs.new(
                 project: project,
                 user: current_user,
                 current_tab: controller.active_project_tab
               ))
      end
    end
  end
end
