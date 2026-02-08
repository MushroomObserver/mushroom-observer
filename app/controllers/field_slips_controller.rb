# frozen_string_literal: true

class FieldSlipsController < ApplicationController
  include Show
  include Index

  before_action :login_required
  # Disable cop: all these methods are defined in files included above.
  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :set_field_slip, only: [:edit, :update, :destroy]
  before_action :login_required, except: [:show]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  # GET /field_slips or /field_slips.json
  #
  # #index - defined in Application Controller

  # GET /field_slips/new
  def new
    @field_slip = FieldSlip.new
    @field_slip.current_user = @user
    @field_slip.code = params[:code].upcase if params.include?(:code)
    @field_slip.field_slip_name = params[:name]
    @species_list = params[:species_list]
    @field_slip.project = Project.safe_find(params[:project]) ||
                          @field_slip.project
    project = @field_slip.project
    if project
      flash_notice(:field_slip_project_success.t(title: project.title))
    else
      flash_notice(:field_slip_cant_join_project.t)
    end
  end

  # GET /field_slips/1/edit
  def edit
    return if @field_slip.can_edit?(@user)

    redirect_to(field_slip_url(id: @field_slip.id))
  end

  # POST /field_slips or /field_slips.json
  def create
    respond_to do |format|
      @field_slip = FieldSlip.new(field_slip_params)
      @field_slip.current_user = @user
      @field_slip.update_project
      check_project_membership
      if check_last_obs && @field_slip.save
        format.html do
          html_create
        end
        format.json { render(:show, status: :created, location: @field_slip) }
      else
        format.html { render(:new, status: :unprocessable_content) }
        format.json do
          render(json: @field_slip.errors, status: :unprocessable_content)
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
                          place_name: place_name,
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
        @field_slip.reload
        format.html { render(:edit, status: :unprocessable_content) }
        format.json do
          render(json: @field_slip.errors, status: :unprocessable_content)
        end
      end
    end
  end

  # DELETE /field_slips/1 or /field_slips/1.json
  def destroy
    unless @field_slip.can_edit?(@user)
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

  def place_name
    str = params[:field_slip][:location]
    @place_name ||= @field_slip.project&.check_for_alias(str, Location) || str
  end

  def set_field_slip
    @field_slip = FieldSlip.find(params[:id])
  end

  def html_create
    if params[:commit] == :field_slip_quick_create_obs.t
      quick_create_observation
    elsif params[:commit] == :field_slip_add_images.t
      redirect_to(new_observation_url(
                    field_code: @field_slip.code,
                    place_name: place_name,
                    date: extract_date,
                    notes: field_slip_notes.compact_blank!,
                    species_list: params[:species_list]
                  ))
    else
      update_observation_fields
      obs = @field_slip.observation
      if obs
        check_for_species_list(obs, params[:species_list])
        redirect_to(observation_url(obs),
                    notice: :field_slip_created.t)
      else
        redirect_to(field_slip_url(@field_slip),
                    notice: :field_slip_created.t)
      end
    end
  end

  def quick_create_observation
    fs_params = params[:field_slip]
    # Must have valid name and location
    location = Location.place_name_to_location(place_name)
    flash_error(:field_slip_quick_no_location.t) unless location
    name = Name.find_by(text_name: fs_params[:field_slip_name])
    notes = field_slip_notes.compact_blank!
    date = extract_date
    obs = Observation.build_observation(location, name, notes, date, @user)
    if obs
      assign_project(obs)
      @field_slip.update!(observation: obs)
      check_for_species_list(obs, params[:species_list])
      name_flash_for_project(name, @field_slip.project)
      redirect_to(observation_url(obs.id))
    else
      redirect_to(new_observation_url(field_code: @field_slip.code,
                                      place_name:, date:, notes:))
    end
  end

  def assign_project(obs)
    project = Project.safe_find(params[:field_slip][:project_id])
    project ||= @filed_slip&.project
    return if project.nil? || project.violates_constraints?(obs)

    project.add_observation(obs)
    @field_slip.update!(project:)
  end

  def check_for_species_list(obs, species_list)
    sl = SpeciesList.safe_find(species_list)
    sl.observations << obs if sl
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
    obs = @field_slip.observation
    return unless obs

    # Don't update Collector
    notes = field_slip_notes
    notes.delete(:Collector) unless @user == obs.user

    check_name
    # Don't override obs.when or obs.place_name
    obs.notes.value_merge!(notes)
    obs.notes.compact_blank!
    obs.save!
  end

  def check_name
    id_str = params[:field_slip][:field_slip_name]
    return unless id_str

    id_str = strip_textile_formatting(id_str)
    names = Name.find_names(@user, id_str)
    return if names.blank?

    name = names[0]
    create_naming_and_vote(name)
  end

  def strip_textile_formatting(id_str)
    # Handle textile formatted IDs defensively
    # "_name Xxx yyy_" -> "Xxx yyy"
    # "_Xxx yyy_" -> "Xxx yyy"
    # "Xxx yyy" -> "Xxx yyy"
    # "_Weird_name_" -> "Weird_name" (preserves internal underscores)
    if id_str.start_with?("_name ") && id_str.end_with?("_")
      # Strip "_name " prefix and trailing "_"
      id_str[6..-2]
    elsif id_str.start_with?("_") && id_str.end_with?("_")
      # Strip leading and trailing underscores only
      id_str[1..-2]
    else
      id_str
    end
  end

  def create_naming_and_vote(name)
    naming = @field_slip.observation.namings.find_by(name:)
    unless naming
      naming = Naming.user_construct({}, @field_slip.observation, @user)
      naming.name = name
      naming.save!
    end
    return if Vote.find_by(user: @user, naming:)

    Vote.create!(favorite: true, value: Vote.maximum_vote, naming:, user: @user)
    Observation::NamingConsensus.new(@field_slip.observation).
      user_calc_consensus(@user)
  end

  def field_slip_notes
    FieldSlipNotesBuilder.new(params, @field_slip).assemble
  end

  # Only allow a list of trusted parameters through.
  def field_slip_params
    params.require(:field_slip).permit(:observation_id, :project_id, :code)
  end

  def check_project_membership
    project = @field_slip&.project
    return unless project&.can_join?(@user)

    user = @user
    project.user_group.users << user
    project_member = ProjectMember.find_by(project:, user:)
    flash_notice(:field_slip_welcome.t(title: project.title))
    return if project_member

    ProjectMember.create(project:, user:, trust_level: "editing")
    flash_notice(:add_members_with_editing.l)
  end

  def disconnect_observation(obs)
    return if params[:commit] == :field_slip_keep_obs.t

    proj = @field_slip.project
    return unless proj && obs
    return if FieldSlip.find_by(observation: obs, project: proj)

    flash_warning(:field_slip_remove_observation.t(
                    observation: obs.user_unique_format_name(@user),
                    title: proj.title
                  ))
    proj.remove_observation(obs)
  end

  def check_last_obs
    return true unless params[:commit] == :field_slip_last_obs.t

    obs = ObservationView.previous(@user, @field_slip.observation)
    return false unless obs # This should not ever happen

    project = @field_slip.project
    if project
      return false unless project.user_can_add_observation?(obs, @user)

      if project.violates_constraints?(obs)
        flash_error(:field_slip_constraint_violation.t)
        return false
      end
      project.add_observation(obs)
    end
    @field_slip.observation = obs
    true
  end
end
