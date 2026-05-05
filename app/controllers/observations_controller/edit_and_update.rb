# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::EditAndUpdate
  include ObservationsController::SharedFormMethods
  include ObservationsController::Validators
  include ::Locationable

  # Form to edit an existing observation.
  # Linked from: left panel
  #
  #
  #
  # Inputs:
  #   params[:id]                       observation id
  #   params[:observation][...]         observation args
  #   params[:observation][:image][n][...]       image args
  #   params[:log_change]               log change in RSS feed?
  #
  # Outputs:
  #   @observation                      populated object
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already attached
  #
  def edit
    return unless find_observation!

    # Make sure user owns this observation!
    unless permission!(@observation)
      redirect_to(action: :show, id: @observation.id) and return
    end

    init_license_var
    init_new_image_var(@observation.when)

    # Initialize form. Put the thumb image first.
    @images      = []
    @good_images = @observation.images_sorted
    @sibling_images = occurrence_sibling_images
    @exif_data = get_exif_data(@good_images)
    @location = @observation.location
    init_project_vars_for_edit(@observation)
    init_list_vars_for_edit(@observation)
  end

  private

  def find_observation!
    @observation = Observation.edit_includes.safe_find(params[:id]) ||
                   flash_error_and_goto_index(Observation, params[:id])
  end

  def init_project_vars_for_edit(obs)
    init_project_vars
    obs.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
      @project_checks[proj.id] = true
    end
  end

  def init_list_vars_for_edit(obs)
    init_list_vars
    obs.species_lists.each do |list|
      @lists << list unless @lists.include?(list)
      @list_checks[list.id] = true
    end
  end

  ##############################################################################

  public

  def update
    return unless find_observation!
    return redirect_to(action: :show, id: @observation.id) \
      unless permission!(@observation)

    init_update
    apply_observation_changes
    reload_edit_form and return if @any_errors

    update_field_slip
    reload_edit_form and return if @any_errors

    update_projects
    update_species_lists
    redirect_to_observation_or_create_location
  end

  ##############################################################################

  private

  def init_update
    init_license_var
    init_new_image_var(@observation.when)
    @any_errors = false
  end

  def apply_observation_changes
    update_permitted_observation_attributes
    create_location_object_if_new(@observation)
    @observation.notes = notes_to_sym_and_compact
    warn_if_unchecking_specimen_with_records_present!
    strip_images! if @observation.gps_hidden

    validate_place_name
    validate_projects
    detach_removed_images
    try_to_upload_images
    try_to_save_location_if_new(@observation)
    try_to_update_observation_if_there_are_changes
  end

  def warn_if_unchecking_specimen_with_records_present!
    return if @observation.specimen
    return unless @observation.specimen_was

    return if @observation.collection_numbers.empty? &&
              @observation.herbarium_records.empty? &&
              @observation.sequences.empty?

    flash_warning(:edit_observation_turn_off_specimen_with_records_present.t)
  end

  # As of 2024-06-01, users can remove images right on the edit obs form.
  def detach_removed_images
    new_ids = params.dig(:observation, :good_image_ids)&.split || []

    # If it didn't make the cut, remove it.
    @observation.images.each do |img|
      next if new_ids.include?(img.id.to_s)

      @observation.remove_image(img)
      img.log_remove_from(@observation)
      flash_notice(:runtime_image_remove_success.t(id: img.id))
    end
    ensure_thumb_image
  end

  # Fix for issue #3995: update_permitted_observation_attributes runs before
  # detach_removed_images, so the form's blank thumb_image_id overwrites the
  # real value before remove_image can detect it needs reassignment.
  def ensure_thumb_image
    return if @observation.thumb_image_id.present? &&
              valid_thumb_image_ids.include?(@observation.thumb_image_id)

    new_thumb = @observation.next_thumb_image
    @observation.thumb_image = new_thumb
    # Persist immediately so the fix survives even if the rest of the
    # update bails out, matching how remove_image persists detachments.
    return unless @observation.persisted? &&
                  @observation.thumb_image_id_changed?

    @observation.update_columns(thumb_image_id: new_thumb&.id,
                                updated_at: Time.zone.now)
  end

  def occurrence_sibling_images
    return [] unless @observation.occurrence

    @observation.occurrence.observations.
      where.not(id: @observation.id).
      includes(:images).flat_map(&:images).uniq -
      @observation.images
  end

  # Image IDs valid for thumbnail: own images + occurrence sibling images
  def valid_thumb_image_ids
    ids = @observation.image_ids
    if @observation.occurrence
      ids |= @observation.occurrence.observations.
             joins(:images).pluck("images.id")
    end
    ids
  end

  def try_to_upload_images
    update_good_images
    create_image_objects_and_update_bad_images
    attach_good_images
    @any_errors = true if @bad_images.any?
  end

  def try_to_update_observation_if_there_are_changes
    return unless @dubious_where_reasons.blank? && @observation.changed?

    @observation.updated_at = Time.zone.now
    if save_observation
      id = @observation.id
      flash_notice(:runtime_edit_observation_success.t(id: id))
      touch = params[:log_change] == "1"
      @observation.log(:log_observation_updated, touch: touch)
    else
      @any_errors = true
    end
  end

  def update_field_slip
    return unless params.key?(:field_code)

    new_code = params[:field_code].to_s.strip.upcase
    current_code = @observation.field_slip&.code.to_s

    return if new_code == current_code

    if new_code.blank?
      clear_field_slip
    else
      assign_field_slip(new_code)
    end
  end

  def clear_field_slip
    occ = @observation.occurrence
    return unless occ

    if occ.primary_observation_id == @observation.id
      @observation.send(:reassign_occurrence_primary, occ)
    end
    @observation.update!(occurrence: nil)
    return unless Occurrence.exists?(occ.id)

    occ.reload
    occ.destroy_if_incomplete!
  end

  def assign_field_slip(code)
    existed = FieldSlip.exists?(code: code)
    field_slip = FieldSlip.find_or_create_by_code(code, @user)
    unless field_slip
      flash_error(
        :edit_observation_field_slip_invalid.t(code: code)
      )
      @any_errors = true
      return
    end

    flash_notice(:field_slip_created.t(code: field_slip.code)) unless existed
    @observation.field_slip = field_slip
    @observation.save!
    field_slip.adopt_user_from(@observation)
  end

  def reload_edit_form
    @images         = @bad_images
    @new_image.when = @observation.when
    @good_images  ||= @observation.images_sorted
    @exif_data    ||= get_exif_data(@good_images)
    @location     ||= @observation.location
    @field_code     = params[:field_code]
    init_project_vars
    init_project_vars_for_reload
    init_list_vars_for_reload
    render(action: :edit)
  end

  ##############################################################################

  def redirect_to_observation_or_create_location
    if @observation.location_id.nil?
      redirect_to(new_location_path(where: @observation.place_name,
                                    set_observation: @observation.id))
    else
      redirect_to(permanent_observation_path(@observation.id))
    end
  end
end
