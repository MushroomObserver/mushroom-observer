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
    before_action :pass_query_params

    def index
      build_index_with_query
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

      redirect_with_query(project_path(@project))
    end

    #########

    private

    def default_index_subaction
      list_all
    end

    def list_all
      return unless find_project!

      @violations = @project.violations
    end

    def find_project!
      @project = find_or_goto_index(Project, params[:project_id])
    end

    def remove_observation_if_permitted(obs_id)
      return unless (obs = Observation.safe_find(obs_id))
      return unless @project.observations.include?(obs)

      permitted_removers = @project.admin_group_user_ids + [obs.user_id]
      return unless permitted_removers.include?(User.current.id)

      @project.remove_observations([obs])
    end
  end
end
