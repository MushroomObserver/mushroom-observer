# frozen_string_literal: true

class FieldSlipsController < ApplicationController
  include Show
  include Index
  include ObservationHandling

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
    @recent_observations = recent_observations_for_field_slip
    project = @field_slip.project
    if project
      flash_notice(:field_slip_project_success.t(title: project.title))
    else
      flash_notice(:field_slip_cant_join_project.t)
    end
  end

  # GET /field_slips/1/edit
  def edit
    unless @field_slip.can_edit?(@user)
      return redirect_to(field_slip_url(id: @field_slip.id))
    end

    @recent_observations = recent_edit_observations
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
            sync_selected_observations
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
      return redirect_to(field_slip_url(id: @field_slip.id))
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
      attach_selected_observations
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

  def field_slip_notes
    FieldSlipNotesBuilder.new(params, @field_slip).assemble
  end

  def recent_edit_observations
    current_ids = @field_slip.observation_ids
    ObservationView.where(user: @user).
      where.not(observation_id: current_ids).
      order(last_view: :desc).limit(4).
      includes(observation: [:name, :user, :location,
                             :thumb_image,
                             { occurrence: :field_slip }]).
      filter_map(&:observation)
  end

  def recent_observations_for_field_slip
    ObservationView.where(user: @user).
      order(last_view: :desc).limit(4).
      includes(observation: [:name, :user, :location,
                             :thumb_image,
                             { occurrence: :field_slip }]).
      filter_map(&:observation)
  end

  def attach_selected_observations
    obs_ids = Array(params[:observation_ids]).map(&:to_i)
    return if obs_ids.empty?

    selected = Observation.where(id: obs_ids).
               includes({ occurrence: :field_slip }).to_a
    ensure_occurrence_for_field_slip(selected)
  end

  def sync_selected_observations
    return unless params.key?(:observation_ids)

    selected_ids = Array(params[:observation_ids]).to_set(&:to_i)
    occ = @field_slip.occurrence
    return create_new_field_slip_occurrence(selected_ids) unless occ

    sync_occurrence_observations(occ, selected_ids)
  end

  def create_new_field_slip_occurrence(selected_ids)
    return if selected_ids.empty?

    selected = Observation.where(id: selected_ids).to_a
    ensure_occurrence_for_field_slip(selected)
  end

  def sync_occurrence_observations(occ, selected_ids)
    current_ids = occ.observation_ids.to_set

    # Detach unchecked observations
    (current_ids - selected_ids).each do |obs_id|
      obs = Observation.find_by(id: obs_id)
      next unless obs

      occ.reassign_thumbnails_from(obs)
      obs.update!(occurrence: nil)
      Observation::NamingConsensus.new(obs).calc_consensus
    end

    # Attach newly checked observations
    (selected_ids - current_ids).each do |obs_id|
      obs = Observation.find_by(id: obs_id)
      obs&.update!(occurrence: occ)
    end

    occ.reload
    update_occurrence_primary(occ)
    occ.recompute_has_specimen!
    occ.recalculate_consensus! unless occ.destroyed?
  end

  def update_occurrence_primary(occ)
    primary = resolve_primary(occ.observations.to_a)
    occ.update!(primary_observation: primary)
  end

  def resolve_primary(obs_list)
    primary_id = params.dig(:field_slip,
                            :primary_observation_id).to_i
    obs_list.find { |o| o.id == primary_id } || obs_list.first
  end

  def ensure_occurrence_for_field_slip(selected)
    primary = resolve_primary(selected)
    occ = @field_slip.occurrence
    if occ
      selected.each do |obs|
        obs.update!(occurrence: occ) unless obs.occurrence_id == occ.id
      end
      occ.update!(primary_observation: primary)
    else
      occ = Occurrence.create!(user: @user,
                               primary_observation: primary,
                               field_slip: @field_slip)
      selected.each { |obs| obs.update!(occurrence: occ) }
    end
    occ.recompute_has_specimen!
    occ.recalculate_consensus!
  rescue ActiveRecord::RecordInvalid => e
    flash_error(e.message)
  end

  # Only allow a list of trusted parameters through.
  def field_slip_params
    params.require(:field_slip).permit(:project_id, :code)
  end

  def check_project_membership
    project = @field_slip&.project
    return unless project&.can_join?(@user)

    project.user_group.users << @user
    flash_notice(:field_slip_welcome.t(title: project.title))
    return if ProjectMember.find_by(project:, user: @user)

    ProjectMember.create(project:, user: @user,
                         trust_level: "editing")
    flash_notice(:add_members_with_editing.l)
  end
end
