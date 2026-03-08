# frozen_string_literal: true

# Controls creating Occurrences (groups of Observations of the same
# specimen). Show/Edit are handled in later phases.
class OccurrencesController < ApplicationController
  before_action :login_required

  def new
    @source_obs = find_source_observation!
    return unless @source_obs

    if @source_obs.occurrence
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

    default_obs = resolve_default_observation(selected)
    occurrence = Occurrence.create_manual(
      default_obs, selected, @user
    )
    flash_notice(:occurrence_created.t(id: occurrence.id))
    redirect_to(permanent_observation_path(@source_obs.id))
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
          includes(:field_slip, :occurrence, :user,
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

  def resolve_default_observation(selected)
    default_id = params.dig(:occurrence,
                            :default_observation_id).to_i
    selected.find { |o| o.id == default_id } || @source_obs
  end

  def render_new_form(source_obs)
    recent = recent_observations(source_obs)
    render(
      Views::Controllers::Occurrences::New.new(
        source_obs: source_obs,
        recent_observations: recent,
        user: @user
      ),
      layout: true
    )
  end
end
