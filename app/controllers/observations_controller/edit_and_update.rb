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
  #   params[:image][n][...]            image args
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

    # Make sure user owns this observation!
    unless permission!(@observation)
      redirect_to(action: :show, id: @observation.id) and return
    end

    init_license_var
    init_new_image_var(@observation.when)
    @any_errors = false

    update_permitted_observation_attributes # may set a new location_id
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

    reload_edit_form and return if @any_errors

    update_projects
    update_species_lists
    redirect_to_observation_or_create_location
  end

  ##############################################################################

  private

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
    new_ids = params[:good_image_ids]&.split || []

    # If it didn't make the cut, remove it.
    @observation.images.each do |img|
      next if new_ids.include?(img.id.to_s)

      @observation.remove_image(img)
      img.log_remove_from(@observation)
      flash_notice(:runtime_image_remove_success.t(id: img.id))
    end
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

  def reload_edit_form
    @images         = @bad_images
    @new_image.when = @observation.when
    @good_images  ||= @observation.images_sorted
    @exif_data    ||= get_exif_data(@good_images)
    @location     ||= @observation.location
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
