# frozen_string_literal: true

module Projects
  class UpdatesController < ApplicationController
    before_action :login_required
    before_action :set_project
    before_action :require_admin

    def index
      results = build_index_results
      render(Views::Controllers::Projects::Updates::Index.new(
               project: @project, user: @user, results: results,
               show_excluded: show_excluded?
             ), layout: true)
    end

    # Single observation add via Turbo. If excluded, un-excludes as a side
    # effect inside Project#add_observation.
    def add_observation
      obs = Observation.safe_find(params[:id])
      if obs
        @project.add_observation(obs)
        render_footer_update(obs)
      else
        head(:not_found)
      end
    end

    # Single observation exclude via Turbo.
    def exclude_observation
      obs = Observation.safe_find(params[:id])
      if obs
        @project.exclude_observation(obs)
        render_footer_update(obs)
      else
        head(:not_found)
      end
    end

    # Bulk add all observations on the current filtered list.
    def add_all
      count = bulk_add_candidates(current_scope)
      flash_notice(:project_updates_added_all.t(count: count))
      redirect_to(project_updates_path(project_id: @project.id,
                                       show_excluded: show_excluded?))
    end

    private

    def set_project
      @project = find_or_goto_index(Project, params[:project_id])
    end

    def show_excluded?
      params[:show_excluded].present? &&
        params[:show_excluded] != "false" &&
        params[:show_excluded] != "0"
    end

    # The observation list the Updates tab is currently showing.
    def current_scope
      if show_excluded?
        @project.excluded_observations.order(created_at: :desc)
      else
        @project.new_candidate_observations
      end
    end

    def build_index_results
      scope = current_scope
      pagination = build_pagination(scope)
      obs_page = paginated_observations(scope, pagination)
      { observations: obs_page,
        pagination: pagination,
        current_count: pagination.num_total,
        base_url: request.path }
    end

    def build_pagination(scope)
      pagination = PaginationData.new(
        number_arg: :page,
        number: params[:page],
        num_per_page: calc_layout_params["count"]
      )
      pagination.num_total = scope.count
      pagination
    end

    def paginated_observations(scope, pagination)
      scope.
        offset(pagination.from).
        limit(pagination.num_per_page).
        includes(
          observation_matrix_box_image_includes,
          :location, :name, :rss_log, :user,
          { namings: :votes },
          { occurrence: :observations }, :projects
        )
    end

    def require_admin
      return if @project&.is_admin?(@user)

      flash_error(:permission_denied.t)
      redirect_to(project_path(@project))
    end

    def render_footer_update(obs)
      respond_to do |format|
        format.turbo_stream do
          render(
            partial: "projects/updates/footer_update",
            locals: { project: @project, obs: obs,
                      count_label: count_label_for_current_scope }
          )
        end
        format.html do
          redirect_back(
            fallback_location: project_updates_path(
              project_id: @project.id, show_excluded: show_excluded?
            )
          )
        end
      end
    end

    def count_label_for_current_scope
      count = current_scope.count
      key = count_label_key
      key.t(count: count)
    end

    def count_label_key
      return :project_updates_excluded_count if show_excluded?

      :project_updates_count
    end

    def bulk_add_candidates(scope)
      count = 0
      scope.find_each do |obs|
        @project.add_observation(obs)
        count += 1
      end
      count
    end
  end
end
