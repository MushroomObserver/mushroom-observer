# frozen_string_literal: true

class FieldSlipsController < ApplicationController
  before_action :set_field_slip, only: [:edit, :update, :destroy]
  before_action :login_required, except: [:show]

  # GET /field_slips or /field_slips.json
  def index
    @field_slips = FieldSlip.includes(
      [{ observation: [:location, :name, :namings, :rss_log, :user] },
       :project, :user]
    )
  end

  # GET /field_slips/1 or /field_slips/1.json
  def show
    obs = nil
    if params[:id].match?(/^\d+$/)
      set_field_slip
    else
      @field_slip = FieldSlip.find_by(code: params[:id].upcase)
      obs = @field_slip&.observation
    end
    if @field_slip
      redirect_to(observation_url(id: obs.id)) if obs
    else
      redirect_to(new_field_slip_url(code: params[:id].upcase))
    end
  end

  # GET /field_slips/new
  def new
    @field_slip = FieldSlip.new
    @field_slip.code = params[:code].upcase if params.include?(:code)
  end

  # GET /field_slips/1/edit
  def edit
    return unless @field_slip.user != User.current

    redirect_to(field_slip_url(id: @field_slip.id))
  end

  # POST /field_slips or /field_slips.json
  def create
    @field_slip = FieldSlip.new(field_slip_params)

    respond_to do |format|
      check_project_membership
      check_for_last_obs
      if params[:commit] == :field_slip_last_obs.t
        @field_slip.observation = ObservationView.last(User.current)
      end
      if @field_slip.save
        format.html do
          if params[:commit] == :field_slip_create_obs.t
            redirect_to(new_observation_url(field_code: @field_slip.code))
          else
            redirect_to(field_slip_url(@field_slip),
                        notice: :field_slip_created.t)
          end
        end
        format.json { render(:show, status: :created, location: @field_slip) }
      else
        format.html { render(:new, status: :unprocessable_entity) }
        format.json do
          render(json: @field_slip.errors, status: :unprocessable_entity)
        end
      end
    end
  end

  # PATCH/PUT /field_slips/1 or /field_slips/1.json
  def update
    respond_to do |format|
      check_for_last_obs
      if @field_slip.update(field_slip_params)
        format.html do
          if params[:commit] == :field_slip_create_obs.t
            redirect_to(new_observation_url(
                          field_code: @field_slip.code,
                          collector:, field_slip_id:, field_slip_id_by:
                        ))
          else
            update_observation_fields(@field_slip.observation)
            redirect_to(field_slip_url(@field_slip),
                        notice: :field_slip_updated.t)
          end
        end
        format.json { render(:show, status: :ok, location: @field_slip) }
      else
        format.html { render(:edit, status: :unprocessable_entity) }
        format.json do
          render(json: @field_slip.errors, status: :unprocessable_entity)
        end
      end
    end
  end

  def update_observation_fields(observation)
    return unless observation

    observation.place_name = params[:field_slip][:location]
    observation.notes[:Collector] = collector
    observation.notes[:Field_Slip_ID] = field_slip_id
    observation.notes[:Field_Slip_ID_By] = field_slip_id_by
    observation.notes[:Other_Codes] = params[:field_slip][:other_codes]
    update_notes_fields(observation)
    observation.notes.compact_blank!
    observation.save!
  end

  def update_notes_fields(observation)
    notes = params[:field_slip][:notes]
    @field_slip.notes_fields.each do |field|
      observation.notes[field.name] = notes[field.name]
    end
  end

  def collector
    user_str(params[:field_slip][:collector])
  end

  def field_slip_id_by
    user_str(params[:field_slip][:field_slip_id_by])
  end

  def field_slip_id
    str = params[:field_slip][:field_slip_id]
    return str if str.empty? || str.starts_with?("_")

    "_#{str}_"
  end

  def user_str(str)
    if str.to_s.match?(/ <.*>$/)
      user = User.find_by(login: str.to_s.sub(/ <.*>$/, ""))
      return "_user #{user.login}_" if user
    end
    str
  end

  # DELETE /field_slips/1 or /field_slips/1.json
  def destroy
    if @field_slip.user != User.current
      redirect_to(field_slip_url(id: @field_slip.id))
      return
    end

    @field_slip.destroy!

    respond_to do |format|
      format.html do
        redirect_to(field_slips_url,
                    notice: :field_slip_destroyed.t)
      end
      format.json { head(:no_content) }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_field_slip
    @field_slip = FieldSlip.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def field_slip_params
    params.require(:field_slip).permit(:observation_id, :project_id, :code)
  end

  def check_project_membership
    project = @field_slip&.project
    return unless project&.can_join?(User.current)

    project.user_group.users << User.current
    flash_notice(:field_slip_welcome.t(title: project.title))
  end

  def check_for_last_obs
    return unless params[:commit] == :field_slip_last_obs.t

    obs = ObservationView.last(User.current)
    @field_slip.observation = obs
    project = @field_slip.project
    return unless obs && project&.user_can_add_observation?(obs, User.current)

    project.add_observation(obs)
  end
end
