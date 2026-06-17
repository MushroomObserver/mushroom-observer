# frozen_string_literal: true

# The action-button row rendered above a project-scoped observations
# index — Map / Images / Download (and, when the project has a
# field-slip prefix, Field Slips). Stashed into
# `content_for(:observation_buttons)` by
# `Views::Controllers::Observations::Index#add_project_observation_buttons`;
# the layout pulls it out when rendering the project chrome.
module Views::Controllers::Projects
  class ObservationButtons < Views::Base
    prop :project, ::Project
    # Required — every render path passes a real `@query` (the obs
    # index always builds one), and both `add_q_param` and
    # `Tab::RelatedQuery.for` rely on the value to mint URLs.
    prop :query, ::Query

    def view_template
      div do
        render_map_button
        render_images_button
        render_download_button
        render_field_slips_button if @project.field_slip_prefix
      end
    end

    private

    def render_map_button
      project_button(:MAP.t, add_q_param(map_observations_path, @query))
    end

    def render_images_button
      images_url = related_observation_images_url
      return unless images_url

      project_button(:IMAGES.l, images_url)
    end

    def render_download_button
      project_button(
        :DOWNLOAD.l, add_q_param(new_observations_download_path, @query)
      )
    end

    def render_field_slips_button
      project_button(:FIELD_SLIPS.t, field_slips_path(project: @project))
    end

    def project_button(name, target)
      render(Components::Button::Project.new(name: name, target: target))
    end

    def related_observation_images_url
      Tab::RelatedQuery.for(
        model: Image, filter: :Observation,
        current_query: @query, controller: controller
      )&.path
    end
  end
end
