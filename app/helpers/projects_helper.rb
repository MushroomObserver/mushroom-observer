# frozen_string_literal: true

# Non-tab helpers for project-related views: the project-banner
# `content_for` setter and the buttons row rendered above the
# project-scoped observation listing on the observations index.
# Sort options now live on `ProjectsController#index_sort_options`.
module ProjectsHelper
  def add_project_banner(project)
    content_for(:project_banner) do
      render(Views::Controllers::Projects::Banner.new(
               project: project,
               user: User.current,
               current_tab: active_project_tab
             ))
    end
  end

  def project_observation_buttons(project, query)
    return unless project

    buttons = base_observation_buttons(query)
    if project.field_slip_prefix
      buttons << project_button(:FIELD_SLIPS.t, field_slips_path(project:))
    end
    content_for(:observation_buttons) { tag.div(safe_join(buttons)) }
  end

  def base_observation_buttons(query)
    [
      project_button(:MAP.t, add_q_param(map_observations_path, query)),
      project_button(:IMAGES.l, related_observation_images_url(query)),
      project_button(:DOWNLOAD.l,
                     add_q_param(new_observations_download_path, query))
    ]
  end

  def project_button(name, target)
    render(Components::ProjectButton.new(name: name, target: target))
  end

  def related_observation_images_url(query)
    Tab::RelatedQuery.for(
      model: Image, filter: :Observation,
      current_query: query, controller: controller
    )&.path
  end
end
