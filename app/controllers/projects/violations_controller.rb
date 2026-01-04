# frozen_string_literal: true

# Show and remove non-compliant Observations from a Project
module Projects
  # Actions
  # -------
  # index (get)
  # edit (get)
  # update (patch)
  #
  class ViolationsController < ApplicationController
    before_action :login_required
    # Cannot figure out the eager loading here.
    around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [:index]

    def index
      return unless find_project!

      @violations = @project.violations
      build_index_with_query
    end

    def controller_model_name
      "Project"
    end

    def update
      unless (@project = find_or_goto_index(Project, params[:project_id]))
        return
      end

      params[:project]&.each do |key, value|
        next unless key =~ /|remove_\d+$/ && value == "1"

        obs_id = key.sub("remove_", "")
        remove_observation_if_permitted(obs_id)
      end

      redirect_to(project_path(@project))
    end

    private

    def find_project!
      @project = Project.violations_includes.find(params[:project_id]) ||
                 flash_error_and_goto_index(Project, params[:project_id])
    end

    def remove_observation_if_permitted(obs_id)
      return unless (obs = Observation.safe_find(obs_id))
      return unless @project.observations.include?(obs)

      permitted_removers = @project.admin_group_user_ids + [obs.user_id]
      return unless permitted_removers.include?(@user.id)

      @project.remove_observations([obs])
    end
  end
end
