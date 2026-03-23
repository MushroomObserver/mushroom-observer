# frozen_string_literal: true

# Controls creating and viewing Occurrences (groups of Observations
# of the same specimen).
class OccurrencesController < ApplicationController
  include Show
  include Edit
  include ResolveProjects

  before_action :login_required

  def new
    @source_obs = find_source_observation!
    return unless @source_obs

    if @source_obs.occurrence&.observations&.many?
      flash_warning(:occurrence_already_exists.t)
      redirect_to(permanent_observation_path(@source_obs.id))
      return
    end

    render_new_form(@source_obs)
  end

  def create
    @source_obs = find_source_observation!
    return unless @source_obs

    selected = build_selected_observations
    return unless selected

    create_occurrence(selected)
  rescue ActiveRecord::RecordInvalid => e
    flash_error(e.message)
    redirect_to(new_occurrence_path(observation_id: @source_obs.id))
  end

  private

  def find_source_observation!
    id = params.dig(:occurrence, :observation_id) ||
         params[:observation_id]
    obs = Observation.safe_find(id)
    return obs if obs

    flash_error(:occurrence_observation_not_found.t)
    redirect_to(observations_path)
    nil
  end

  def recent_observations(source_obs)
    ObservationView.where(user: @user).
      where.not(observation_id: source_obs.id).
      order(last_view: :desc).
      limit(3).
      includes(:observation).
      filter_map(&:observation)
  end

  def build_selected_observations
    ids = Array(params[:observation_ids]).map(&:to_i)
    ids |= [@source_obs.id] # always include source
    obs = Observation.where(id: ids).
          includes({ occurrence: :field_slip }, :user,
                   :location, :name, :thumb_image).to_a

    if obs.size < 2
      flash_error(:occurrence_need_two.t)
      redirect_to(new_occurrence_path(
                    observation_id: @source_obs.id
                  ))
      return nil
    end
    obs
  end

  def create_occurrence(selected)
    primary_obs = resolve_primary_observation(selected)
    gaps = preview_project_gaps(primary_obs, selected)
    if gaps.any? && !params[:project_resolution]
      render_project_confirmation(gaps, selected, primary_obs)
      return
    end

    commit_occurrence(primary_obs, selected, gaps)
  end

  def commit_occurrence(primary_obs, selected, gaps)
    occ = Occurrence.create_manual(primary_obs, selected, @user)
    occ.recalculate_consensus!
    apply_project_resolution(occ, gaps)
    warn_if_locations_differ(selected)
    flash_notice(:occurrence_created.t(id: occ.id))
    redirect_to(occurrence_path(occ.id))
  end

  def resolve_primary_observation(selected)
    primary_id = params.dig(:occurrence,
                            :primary_observation_id).to_i
    selected.find { |o| o.id == primary_id } || @source_obs
  end

  def warn_if_locations_differ(observations)
    return if observations.map(&:place_name).uniq.size <= 1

    flash_warning(:occurrence_locations_differ.t)
  end

  def render_new_form(source_obs)
    recent = recent_observations(source_obs)
    confirm = {}
    if @project_gaps&.any?
      confirm = { gaps: @project_gaps, primary: @project_primary,
                  selected: @project_selected }
    end
    render(
      Views::Controllers::Occurrences::New.new(
        source_obs: source_obs,
        recent_observations: recent,
        user: @user,
        project_confirm: confirm
      ),
      layout: true
    )
  end

  # Check for project membership gaps before creating the occurrence.
  # Returns {} if all observations are in all the same projects,
  # otherwise returns { projects: [Project, ...], has_non_primary_gaps: bool }
  def preview_project_gaps(primary_obs, selected)
    all_projects = all_selected_projects(selected)
    return {} if all_projects.empty?

    primary_missing = all_projects - primary_obs.projects.to_a
    non_primary_gaps = any_non_primary_gaps?(
      primary_obs, selected, all_projects
    )
    return {} if primary_missing.empty? && !non_primary_gaps

    { projects: all_projects,
      primary_missing: primary_missing,
      has_non_primary_gaps: non_primary_gaps }
  end

  def all_selected_projects(selected)
    Project.joins(:project_observations).
      where(project_observations: {
              observation_id: selected.map(&:id)
            }).distinct.to_a
  end

  def any_non_primary_gaps?(primary_obs, selected, all_projects)
    selected.any? do |obs|
      next if obs.id == primary_obs.id

      (all_projects - obs.projects.to_a).any?
    end
  end

  def render_project_confirmation(gaps, selected, primary_obs)
    @project_gaps = gaps
    @project_primary = primary_obs
    @project_selected = selected
    render_new_form(@source_obs)
  end

  def apply_project_resolution(occ, gaps)
    return if gaps.empty?
    return unless params[:project_resolution] == "add_all"

    occ.add_all_to_collections(projects: gaps[:projects] || [])
  end
end
