# frozen_string_literal: true

module Projects
  class UpdatesController < ApplicationController
    before_action :login_required
    before_action :set_project
    before_action :require_admin

    def index
      results = build_index_results
      render(Views::Controllers::Projects::Updates::Index.new(
               project: @project, user: @user, results: results
             ), layout: true)
    end

    # Single observation add via Turbo
    def add_observation
      obs = Observation.safe_find(params[:id])
      if obs
        @project.add_observation(obs)
        render_footer_update(obs)
      else
        head(:not_found)
      end
    end

    # Single observation remove via Turbo
    def remove_observation
      obs = Observation.safe_find(params[:id])
      if obs
        @project.remove_observation(obs)
        render_footer_update(obs)
      else
        head(:not_found)
      end
    end

    # Bulk add all candidates
    def add_all
      count = bulk_add_candidates
      flash_notice(:project_updates_added_all.t(count: count))
      redirect_to(project_updates_path(project_id: @project.id))
    end

    # Bulk remove all candidates from project
    def clear
      count = bulk_remove_candidates
      flash_notice(:project_updates_cleared.t(count: count))
      redirect_to(project_updates_path(project_id: @project.id))
    end

    private

    def set_project
      @project = find_or_goto_index(Project, params[:project_id])
    end

    def build_index_results
      candidates = @project.candidate_observations
      pagination = build_pagination(candidates)
      obs_page = paginated_observations(candidates, pagination)
      page_ids = obs_page.map(&:id)
      member_ids = @project.observations.where(id: page_ids).
                   pluck(:id).to_set
      { observations: obs_page,
        pagination: pagination,
        member_ids: member_ids,
        new_count: @project.new_candidate_observations_count,
        base_url: request.path }
    end

    def build_pagination(candidates)
      pagination = PaginationData.new(
        number_arg: :page,
        number: params[:page],
        num_per_page: calc_layout_params["count"]
      )
      pagination.num_total = candidates.count
      pagination
    end

    def paginated_observations(candidates, pagination)
      candidates.
        offset(pagination.from).
        limit(pagination.num_per_page).
        includes(:name, :location, :user, :thumb_image)
    end

    def require_admin
      return if @project&.is_admin?(@user)

      flash_error(:permission_denied.t)
      redirect_to(project_path(@project))
    end

    def render_footer_update(obs)
      in_project = @project.observations.exists?(obs.id)
      respond_to do |format|
        format.turbo_stream do
          render(
            partial: "projects/updates/footer_update",
            locals: { project: @project, obs: obs,
                      in_project: in_project }
          )
        end
        format.html do
          redirect_to(project_updates_path(project_id: @project.id))
        end
      end
    end

    def bulk_add_candidates
      candidates = @project.candidate_observations.
                   where.not(id: @project.observations.select(:id))
      count = 0
      candidates.find_each do |obs|
        @project.add_observation(obs)
        count += 1
      end
      count
    end

    def bulk_remove_candidates
      in_project = @project.candidate_observations.
                   where(id: @project.observations.select(:id))
      count = 0
      in_project.find_each do |obs|
        @project.remove_observation(obs)
        count += 1
      end
      count
    end
  end
end
