# frozen_string_literal: true

class FieldSlipsController < ApplicationController
  include Show
  include Index

  # Disable cop: all these methods are defined in files included above.
  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :set_field_slip, only: [:edit, :update, :destroy]
  before_action :login_required, except: [:show]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  # NOTE: Must be an ivar of FieldSlipsController
  # Defining them in an index.rb does not work
  @index_subaction_param_keys = [
    :user,
    :observation,
    :project,
    :by,
    :q,
    :id
  ].freeze

  @index_subaction_dispatch_table = {
    by: :index_query_results,
    q: :index_query_results,
    id: :index_query_results
  }.freeze

  # GET /field_slips or /field_slips.json
  #
  # #index - defined in Application Controller

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
                          date: extract_date,
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

  def set_field_slip
    @field_slip = FieldSlip.find(params[:id])
  end

  def html_create
    if params[:commit] == :field_slip_quick_create_obs.t
      quick_create_observation
    elsif params[:commit] == :field_slip_add_images.t
      redirect_to(new_observation_url(
                    field_code: @field_slip.code,
                    place_name: params[:field_slip][:location],
                    date: extract_date,
                    notes: field_slip_notes.compact_blank!
                  ))
    else
      update_observation_fields
      redirect_to(field_slip_url(@field_slip),
                  notice: :field_slip_created.t)
    end
  end

  def quick_create_observation
    fs_params = params[:field_slip]
    place_name = fs_params[:location]
    # Must have valid name and location
    location = Location.place_name_to_location(place_name)
    flash_error(:field_slip_quick_no_location.t) unless location
    name = Name.find_by(text_name: fs_params[:field_slip_name])
    notes = field_slip_notes.compact_blank!
    date = extract_date
    obs = Observation.build_observation(location, name, notes, date)
    if obs
      @field_slip.project&.add_observation(obs)
      @field_slip.update!(observation: obs)
      name_flash_for_project(name, @field_slip.project)
      redirect_to(observation_url(obs.id))
    else
      redirect_to(new_observation_url(field_code: @field_slip.code,
                                      place_name:, date:, notes:))
    end
  end

  def extract_date
    fs_params = params[:field_slip]
    date = nil
    if fs_params["date(1i)"]
      date = Date.new(fs_params["date(1i)"].to_i,
                      fs_params["date(2i)"].to_i,
                      fs_params["date(3i)"].to_i)
    end
    date
  end

  def update_observation_fields
    observation = @field_slip.observation
    return unless observation

    check_name
    observation.when = extract_date
    observation.place_name = params[:field_slip][:location]
    observation.notes.merge!(field_slip_notes)
    observation.notes.compact_blank!
    observation.save!
  end

  def check_name
    id_str = params[:field_slip][:field_slip_name]
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
    notes[:Other_Codes] = other_codes
    update_notes_fields(notes)
    notes
  end

  def other_codes
    codes = params[:field_slip][:other_codes]
    return codes unless params[:field_slip][:inat] == "1"

    "\"iNat ##{codes}\":https://www.inaturalist.org/observations/#{codes}"
  end

  def update_notes_fields(notes)
    new_notes = params[:field_slip][:notes]
    return unless new_notes

    @field_slip.notes_fields.each do |field|
      notes[field.name] = new_notes[field.name]
    end
  end

  def collector = user_str(params[:field_slip][:collector])

  def field_slip_id_by = user_str(params[:field_slip][:field_slip_id_by])

  def field_slip_id
    str = params[:field_slip][:field_slip_name]
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

  # Only allow a list of trusted parameters through.
  def field_slip_params
    params.require(:field_slip).permit(:observation_id, :project_id, :code)
  end

  def check_project_membership
    project = @field_slip&.project
    return unless project&.can_join?(User.current)

    user = User.current
    project.user_group.users << user
    project_member = ProjectMember.find_by(project:, user:)
    flash_notice(:field_slip_welcome.t(title: project.title))
    return if project_member

    ProjectMember.create(project:, user:, trust_level: "hidden_gps")
    flash_notice(:add_members_with_gps_trust.l)
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
