# frozen_string_literal: true

# Show and manage Project constraint violations.
#
# Per #4136, the violations page lists every observation that fails one
# or more of the project's four constraints (date, bbox, target name,
# target location) and offers per-row actions to bring it into
# compliance: Exclude (always), Extend dates (date kind), Add Target
# Name (target_name kind), Add Target Location (target_location kind).
module Projects
  class ViolationsController < ApplicationController
    before_action :login_required
    # Cannot figure out the eager loading here.
    around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [:index]

    def index
      return unless find_project!

      @violations = @project.violations
      build_index_with_query
    end

    # Overrides `ApplicationController::Indexes#render_index_view` so
    # `show_index_of_objects` renders the Phlex `Violations::Index`
    # class instead of `projects/violations/index.html.erb` (deleted).
    def render_index_view
      render(Views::Controllers::Projects::Violations::Index.new(
               project: @project, violations: @violations, user: @user
             ))
    end

    # GET-only turbo-stream endpoint that renders the Add-Target-Location
    # modal for one obs (#4304). Called by the modal-toggle controller
    # in always-fresh mode so each open reflects current DB state —
    # admins frequently create missing suffix Locations in a separate
    # tab and need the modal's radios to pick those up without
    # reloading the violations page.
    #
    # Uses a narrow `find_by` (Copilot review on PR #4307) rather than
    # the index action's `violations_includes` scope — this endpoint
    # renders one obs's suffix radios, so eager-loading the whole
    # observations list per click would be wasteful on large projects.
    # Any missing-id / non-admin case returns :not_found rather than
    # redirecting; the trigger is a turbo-stream fetch, so the
    # redirect-to-index fallback from `find_project!` doesn't fit.
    def target_location_modal
      project = Project.find_by(id: params[:project_id])
      obs = Observation.safe_find(params[:obs_id])
      return head(:not_found) unless project && obs && project.is_admin?(@user)

      respond_to do |format|
        format.turbo_stream do
          render(
            Views::Controllers::Projects::Violations::TargetLocationModal.new(
              project: project, obs: obs, user: @user
            ),
            layout: false
          )
        end
      end
    end

    def controller_model_name
      "Project"
    end

    def update
      @project = find_or_goto_index(Project, params[:project_id])
      return unless @project

      dispatch_action

      redirect_to(project_violations_path(project_id: @project.id))
    end

    private

    # Eager-loaded variant of `find_or_goto_index` for the index
    # action, which renders the full violations list. `find_by`
    # returns nil rather than raising, so the `||` fallback fires
    # cleanly on a missing id.
    def find_project!
      @project = Project.violations_includes.find_by(id: params[:project_id]) ||
                 flash_error_and_goto_index(Project, params[:project_id])
    end

    # All action params (`do`, `obs_id`, `location_id`) are namespaced
    # under `params[:project]` — the form's Superform model is Project,
    # and the button_to calls in `Views::Controllers::Projects::Violations::Form`
    # POST `params: { project: { do: ..., obs_id: ... } }` to match.
    def dispatch_action
      case params.dig(:project, :do)
      when "exclude" then handle_exclude
      when "extend" then handle_extend
      when "add_target_name" then handle_add_target_name
      when "add_target_location" then handle_add_target_location
      else handle_legacy_remove_selected
      end
    end

    def project_obs_id
      params.dig(:project, :obs_id)
    end

    def handle_exclude
      obs = Observation.safe_find(project_obs_id)
      return unless obs && permitted_to_exclude?(obs)

      @project.exclude_observation(obs)
    end

    def handle_extend
      return unless admin?

      obs = Observation.safe_find(project_obs_id)
      return unless obs&.when

      extend_project_dates_to_include(obs.when)
    end

    def handle_add_target_name
      return unless admin?

      obs = Observation.safe_find(project_obs_id)
      name = obs&.name
      return unless name

      @project.add_target_name(name)
    end

    def handle_add_target_location
      return unless admin?

      location = Location.safe_find(params.dig(:project, :location_id))
      return unless location

      @project.add_target_location(location)
    end

    # Back-compat: the old "Remove Selected" form sent
    # params[:project][:remove_<id>] = "1" with no `do` param.
    def handle_legacy_remove_selected
      params[:project]&.each do |key, value|
        next unless key =~ /\Aremove_\d+\z/ && value == "1"

        obs_id = key.sub("remove_", "")
        remove_observation_if_permitted(obs_id)
      end
    end

    def remove_observation_if_permitted(obs_id)
      return unless (obs = Observation.safe_find(obs_id))
      return unless @project.observations.include?(obs)

      permitted_removers = @project.admin_group_user_ids + [obs.user_id]
      return unless permitted_removers.include?(@user.id)

      @project.remove_observations([obs])
    end

    def admin?
      @project.is_admin?(@user)
    end

    def permitted_to_exclude?(obs)
      admin? || obs.user_id == @user.id
    end

    def extend_project_dates_to_include(date)
      changes = {}
      if @project.start_date && date < @project.start_date
        changes[:start_date] = date
      end
      changes[:end_date] = date if @project.end_date && date > @project.end_date
      return if changes.empty?

      @project.update!(changes)
    end
  end
end
