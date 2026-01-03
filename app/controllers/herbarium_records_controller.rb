# frozen_string_literal: true

# Controls viewing and modifying herbarium records.
# rubocop:disable Metrics/ClassLength
class HerbariumRecordsController < ApplicationController
  before_action :login_required
  before_action :store_location, except: [:destroy]

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    ::Query::Herbaria.default_order # :name
  end

  # ApplicationController uses this table to dispatch #index to a private method
  def index_active_params
    [:pattern, :herbarium, :observation, :by, :q, :id].freeze
  end

  def herbarium
    query = create_query(:HerbariumRecord,
                         herbaria: params[:herbarium].to_s,
                         order_by: :herbarium_label)
    [query, { always_index: true }]
  end

  def observation
    @observation = Observation.find(params[:observation])
    query = create_query(:HerbariumRecord,
                         observations: params[:observation].to_s,
                         order_by: :herbarium_label)
    [query, { always_index: true }]
  end

  def index_display_opts(opts, _query)
    {
      letters: true,
      num_per_page: 100,
      include: [{ herbarium: :curators }, { observations: :name }, :user]
    }.merge(opts)
  end

  public

  ####################################################################

  def show
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, HerbariumRecord, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, HerbariumRecord, params[:id]) and return
    end

    @layout = calc_layout_params
    @canonical_url = HerbariumRecord.show_url(params[:id])
    find_herbarium_record!
  end

  def new
    set_ivars_for_new

    @back_object = @observation
    @herbarium_record = default_herbarium_record

    respond_to do |format|
      format.turbo_stream { render_modal_herbarium_record_form }
      format.html
    end
  end

  def create
    set_ivars_for_new

    @back_object = @observation
    create_herbarium_record # response handled here
  end

  def edit
    set_ivars_for_edit

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!

    @herbarium_record.herbarium_name = @herbarium_record.herbarium.try(&:name)

    respond_to do |format|
      format.turbo_stream { render_modal_herbarium_record_form }
      format.html
    end
  end

  def update
    set_ivars_for_edit

    figure_out_where_to_go_back_to
    return unless make_sure_can_edit!

    update_herbarium_record # response handled here
  end

  # Handles both full destroy and remove-from-observation.
  # If observation_id param present: removes association (destroys if last obs)
  # If observation_id param absent: destroys the herbarium_record directly
  def destroy
    @herbarium_record = find_or_goto_index(HerbariumRecord, params[:id])
    return unless @herbarium_record
    return unless make_sure_can_delete!(@herbarium_record)
    return unless execute_destroy!

    respond_to_destroy
  end

  ##############################################################################

  private

  def set_ivars_for_new
    @layout = calc_layout_params
    @observation = find_or_goto_index(Observation, params[:observation_id])
  end

  def set_ivars_for_edit
    @layout = calc_layout_params
    find_herbarium_record!
  end

  def find_herbarium_record!
    @herbarium_record = HerbariumRecord.includes(herbarium_record_includes).
                        find_by(id: params[:id]) ||
                        flash_error_and_goto_index(
                          HerbariumRecord, params[:id]
                        )
  end

  def herbarium_record_includes
    [:user,
     { observations: [:user, observation_matrix_box_image_includes] }]
  end

  def default_herbarium_record
    HerbariumRecord.new(
      herbarium_name: @user.preferred_herbarium_name,
      initial_det: @observation.name.text_name,
      accession_number: default_accession_number
    )
  end

  def default_accession_number
    if @observation.field_slips.length == 1
      @observation.field_slips.first.code
    elsif @observation.collection_numbers.length == 1
      @observation.collection_numbers.first.format_name
    else
      "MO #{@observation.id}"
    end
  end

  # create
  def create_herbarium_record
    @herbarium_record =
      HerbariumRecord.new(permitted_herbarium_record_params)
    normalize_parameters
    return if form_has_errors?

    if herbarium_label_free?
      save_herbarium_record_and_update_associations
      return
    end

    if @other_record.can_edit?
      flash_herbarium_record_already_used_and_add_observation
    else
      flash_herbarium_record_already_used_by_someone_else
    end
    show_flash_and_send_back
  end

  # create
  def save_herbarium_record_and_update_associations
    @herbarium_record.save
    @herbarium_record.add_observation(@observation)
    flash_notice(
      :runtime_added_to.t(type: :herbarium_record, name: :observation)
    )

    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @herbarium_record)
      end
      format.turbo_stream do
        render_herbarium_records_section_update
      end
    end
  end

  # create
  def flash_herbarium_record_already_used_and_add_observation
    flash_warning(:create_herbarium_record_already_used.t) if
      @other_record.observations.any?
    @other_record.add_observation(@observation)
  end

  # create
  def flash_herbarium_record_already_used_by_someone_else
    flash_error(:create_herbarium_record_already_used_by_someone_else.
      t(herbarium_name: @herbarium_record.herbarium.name))
  end

  # update
  def update_herbarium_record
    old_herbarium = @herbarium_record.herbarium
    @herbarium_record.attributes = permitted_herbarium_record_params
    normalize_parameters
    return if form_has_errors?

    if herbarium_label_free?
      update_herbarium_record_and_notify_curators(old_herbarium)
    else
      flash_warning(:edit_herbarium_record_already_used.t)
      show_flash_and_send_back
    end
  end

  # update
  def update_herbarium_record_and_notify_curators(old_herbarium)
    @herbarium_record.save
    @herbarium_record.notify_curators if
      @herbarium_record.herbarium != old_herbarium
    flash_notice(:runtime_updated_at.t(type: :herbarium_record))

    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @herbarium_record)
      end
      @observation = @back_object # if we're here, we're on an obs page
      format.turbo_stream do
        render_herbarium_records_section_update
      end
    end
  end

  # create, update
  def form_has_errors?
    unless validate_herbarium_name! # may add flashes
      flash_and_reload_form
      return true
    end

    unless can_add_record_to_herbarium?
      show_flash_and_send_back
      return true
    end

    false
  end

  def flash_and_reload_form
    redirect_params = case action_name # this is a rails var
                      when "create"
                        { action: :new }
                      when "update"
                        { action: :edit }
                      end
    redirect_params[:back] = @back if @back.present?

    respond_to do |format|
      format.html do
        redirect_to(redirect_params)
      end
      format.turbo_stream do
        reload_herbarium_record_modal_form_and_flash
      end
    end
  end

  def permitted_herbarium_record_params
    return {} unless params[:herbarium_record]

    params.require(:herbarium_record).
      permit(:herbarium_name, :initial_det, :accession_number, :notes)
  end

  def make_sure_can_edit!
    return true if in_admin_mode? || @herbarium_record.can_edit?
    return true if @herbarium_record.herbarium.curator?(@user)

    flash_error(:permission_denied.t)
    show_flash_and_send_back
    false
  end

  def make_sure_can_delete!(herbarium_record)
    return true if herbarium_record.can_edit? || in_admin_mode?
    return true if herbarium_record.herbarium.curator?(@user)

    flash_error(:permission_denied.t)
    redirect_to(herbarium_record_path(herbarium_record))
    false
  end

  # Returns false if observation lookup fails, halting destroy action
  def execute_destroy!
    if params[:observation_id].present?
      @observation = find_or_goto_index(Observation, params[:observation_id])
      return false unless @observation

      @herbarium_record.remove_observation(@observation)
      flash_notice(:runtime_removed.t(type: :herbarium_record))
    else
      # Figure out where to redirect BEFORE destroying the record
      figure_out_destroy_redirect
      @herbarium_record.destroy
    end
    true
  end

  # Determine @observation for redirect after destroy.
  # Must be called before destroy since we need to check observations.
  def figure_out_destroy_redirect
    back = params[:back].to_s
    @observation = nil
    return if back == "index"

    # If back is an observation ID, use that
    @observation = Observation.safe_find(back)
    return if @observation

    # If record has exactly one observation, redirect there
    @observation = @herbarium_record.observations.first if
      @herbarium_record.observations.one?
  end

  def respond_to_destroy
    respond_to do |format|
      format.turbo_stream { destroy_turbo_response }
      format.html { destroy_html_response }
    end
  end

  def destroy_turbo_response
    # Only render turbo_stream update if we have an observation page to update.
    # Can't update show page via turbo_stream, so redirect to index.
    if @observation && params[:back] != "show"
      render_herbarium_records_section_update
    else
      redirect_with_query(action: :index)
    end
  end

  def destroy_html_response
    if @observation
      redirect_to(observation_path(@observation.id))
    else
      redirect_with_query(action: :index)
    end
  end

  def normalize_parameters
    [:herbarium_name, :initial_det, :accession_number].each do |arg|
      val = @herbarium_record.send(arg).to_s.strip_html.strip_squeeze
      @herbarium_record.send(:"#{arg}=", val)
    end
    @herbarium_record.notes = @herbarium_record.notes.to_s.strip
  end

  def validate_herbarium_name!
    name = @herbarium_record.herbarium_name.to_s
    name2 = name.sub(/^[^-]* - /, "")
    herbarium = Herbarium.where(name: [name, name2]).first ||
                Herbarium.where(code: name).first
    @herbarium_record.herbarium = herbarium
    if name.blank?
      flash_error(:create_herbarium_record_missing_herbarium_name.t)
      false
    elsif !@herbarium_record.herbarium_id.nil?
      true
    elsif name != @user.personal_herbarium_name || @user.personal_herbarium
      flash_warning(:create_herbarium_separately.t)
      false
    else
      @herbarium_record.herbarium = @user.create_personal_herbarium
      true
    end
  end

  def can_add_record_to_herbarium?
    return true if in_admin_mode?
    return true if @observation&.can_edit?
    return true if @herbarium_record.observations.any?(&:can_edit?)
    return true if @herbarium_record.herbarium.curator?(@user)

    flash_error(:create_herbarium_record_only_curator_or_owner.t)
    false
  end

  def herbarium_label_free?
    @other_record = HerbariumRecord.where(
      herbarium: @herbarium_record.herbarium,
      accession_number: @herbarium_record.accession_number
    ).first
    !@other_record || @other_record == @herbarium_record
  end

  def figure_out_where_to_go_back_to
    @back = params[:back].to_s
    @back_object = nil
    if @back == "show"
      @back_object = @herbarium_record
    elsif @back != "index"
      @back_object = Observation.safe_find(@back)
      return if @back_object

      @back_object = if @herbarium_record.observations.one?
                       @herbarium_record.observations.first
                     else
                       @herbarium_record
                     end
    end
  end

  def show_flash_and_send_back
    respond_to do |format|
      format.html do
        redirect_to_back_object_or_object(@back_object, @herbarium_record) and
          return
      end
      format.turbo_stream do
        # renders the flash in the modal via js
        render(partial: "shared/modal_flash_update",
               locals: { identifier: modal_identifier }) and return
      end
    end
  end

  def render_modal_herbarium_record_form
    render(Components::ModalForm.new(
             identifier: modal_identifier,
             title: modal_title,
             user: @user,
             model: @herbarium_record,
             observation: @observation,
             back: @back
           ))
  end

  def modal_identifier
    case action_name
    when "new", "create"
      "herbarium_record"
    when "edit", "update"
      "herbarium_record_#{@herbarium_record.id}"
    end
  end

  def modal_title
    case action_name
    when "new", "create"
      helpers.new_page_title(:add_object, :HERBARIUM_RECORD)
    when "edit", "update"
      helpers.edit_page_title(
        [@herbarium_record.format_name.t,
         @herbarium_record.herbarium_label].safe_join(" "),
        @herbarium_record
      )
    end
  end

  def render_herbarium_records_section_update
    render(
      partial: "observations/show/section_update",
      locals: { identifier: "herbarium_records",
                obs: @observation, user: @user }
    ) and return
  end

  # this updates both the form and the flash
  def reload_herbarium_record_modal_form_and_flash
    render(
      partial: "shared/modal_form_reload",
      locals: {
        identifier: modal_identifier,
        form_locals: {
          model: @herbarium_record,
          observation: @observation
        }
      }
    ) and return true
  end
end
# rubocop:enable Metrics/ClassLength
