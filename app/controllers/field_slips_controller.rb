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

  # GET /field_slips/1 or /field_slips/1.json or /qr/XYZ-123
  def show
    obs = nil
    if params[:id].match?(/^\d+$/)
      set_field_slip
    else
      @field_slip = FieldSlip.find_by(code: params[:id].upcase)
      obs = @field_slip&.observation
    end
    if @field_slip
      field_slip_redirect(obs.id) if obs
    else
      redirect_to(new_field_slip_url(code: params[:id].upcase))
    end
  end

  # GET /field_slips/new
  def new
    @field_slip = FieldSlip.new
    @field_slip.code = params[:code].upcase if params.include?(:code)
    project = @field_slip.project
    if project
      flash_notice(:field_slip_project_success.t(title: project.title))
    else
      flash_notice(:field_slip_cant_join_project.t)
    end
  end

  # GET /field_slips/1/edit
  def edit
    return if @field_slip.can_edit?

    redirect_to(field_slip_url(id: @field_slip.id))
  end

  # POST /field_slips or /field_slips.json
  def create
    respond_to do |format|
      @field_slip = FieldSlip.new(field_slip_params)
      check_project_membership
      if check_last_obs && @field_slip.save
        format.html do
          html_create
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
    old_obs = @field_slip.observation
    respond_to do |format|
      if check_last_obs && @field_slip.update(field_slip_params)
        format.html do
          disconnect_observation(old_obs)
          if params[:commit] == :field_slip_create_obs.t
            redirect_to(new_observation_url(
                          field_code: @field_slip.code,
                          place_name: params[:field_slip][:location],
                          notes: field_slip_notes.compact_blank!
                        ))
          else
            update_observation_fields
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

  # DELETE /field_slips/1 or /field_slips/1.json
  def destroy
    unless @field_slip.can_edit?
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

  def field_slip_redirect(obs_id)
    if foray_recorder?
      redirect_to(edit_field_slip_url(id: @field_slip.id))
    else
      redirect_to(observation_url(id: obs_id))
    end
  end

  def foray_recorder?
    project = @field_slip&.project
    return false unless project

    project.is_admin?(User.current) && project.happening?
  end

  def html_create
    if params[:commit] == :field_slip_quick_create_obs.t
      quick_create_observation
    elsif params[:commit] == :field_slip_add_images.t
      redirect_to(new_observation_url(
                    field_code: @field_slip.code,
                    place_name: params[:field_slip][:location],
                    notes: field_slip_notes.compact_blank!
                  ))
    else
      update_observation_fields
      redirect_to(field_slip_url(@field_slip),
                  notice: :field_slip_created.t)
    end
  end

  def quick_create_observation
    place_name = params[:field_slip][:location]
    # Must have valid name and location
    location = Location.place_name_to_location(place_name)
    flash_error(:field_slip_quick_no_location.t) unless location
    name = Name.find_by(text_name: params[:field_slip][:field_slip_id])
    flash_error(:field_slip_quick_no_name.t) unless name
    notes = field_slip_notes.compact_blank!

    obs = Observation.build_observation(location, name, notes)
    if obs
      @field_slip.project&.add_observation(obs)
      @field_slip.update!(observation: obs)
      redirect_to(observation_url(obs.id))
    else
      redirect_to(new_observation_url(field_code: @field_slip.code,
                                      place_name:, notes:))
    end
  end

  def update_observation_fields
    observation = @field_slip.observation
    return unless observation

    check_name
    observation.place_name = params[:field_slip][:location]
    observation.notes.merge!(field_slip_notes)
    observation.notes.compact_blank!
    observation.save!
  end

  def check_name
    id_str = params[:field_slip][:field_slip_id]
    return unless id_str

    id_str.tr!("_", "")
    names = Name.find_names(id_str)
    return if names.blank?

    name = names[0]
    naming = @field_slip.observation.namings.find_by(name:)
    unless naming
      naming = Naming.construct({}, @field_slip.observation)
      naming.name = name
      naming.save!
    end
    vote = Vote.find_by(user: User.current, naming:)
    return if vote

    Vote.create!(favorite: true, value: Vote.maximum_vote, naming:)
    Observation::NamingConsensus.new(@field_slip.observation).calc_consensus
  end

  def field_slip_notes
    notes = {}
    notes[:Collector] = collector
    notes[:Field_Slip_ID] = field_slip_id
    notes[:Field_Slip_ID_By] = field_slip_id_by
    notes[:Other_Codes] = params[:field_slip][:other_codes]
    update_notes_fields(notes)
    notes
  end

  def update_notes_fields(notes)
    new_notes = params[:field_slip][:notes]
    return unless new_notes

    @field_slip.notes_fields.each do |field|
      notes[field.name] = new_notes[field.name]
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

  def disconnect_observation(obs)
    return if params[:commit] == :field_slip_keep_obs.t

    proj = @field_slip.project
    return unless proj && obs
    return if FieldSlip.find_by(observation: obs, project: proj)

    flash_warning(:field_slip_remove_observation.t(
                    observation: obs.unique_format_name,
                    title: proj.title
                  ))
    proj.remove_observation(obs)
  end

  def check_last_obs
    return true unless params[:commit] == :field_slip_last_obs.t

    obs = ObservationView.previous(User.current, @field_slip.observation)
    return false unless obs # This should not ever happen

    project = @field_slip.project
    if project
      return false unless project.user_can_add_observation?(obs, User.current)

      if project.violates_constraints?(obs)
        if project.admin?(User.current)
          flash_warning(:field_slip_constraint_violation.t)
        else
          flash_error(:field_slip_constraint_violation.t)
          return false
        end
      end
      project.add_observation(obs)
    end
    @field_slip.observation = obs
    true
  end
end
