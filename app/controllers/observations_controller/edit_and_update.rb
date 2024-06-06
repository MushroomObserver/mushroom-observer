# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::EditAndUpdate
  include ObservationsController::FormHelpers
  include ObservationsController::Validators

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
    return unless (@observation = find_or_goto_index(
      Observation, params[:id].to_s
    ))

    # Make sure user owns this observation!
    unless check_permission!(@observation)
      redirect_with_query(action: :show, id: @observation.id) and return
    end

    init_license_var
    init_new_image_var(@observation.when)

    # Initialize form. Put the thumb image first.
    @images      = []
    @good_images = @observation.images_sorted
    init_project_vars_for_edit(@observation)
    init_list_vars_for_edit(@observation)
  end

  private

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
    return unless (@observation = find_or_goto_index(
      Observation, params[:id].to_s
    ))

    # Make sure user owns this observation!
    unless check_permission!(@observation)
      redirect_with_query(action: :show, id: @observation.id) and return
    end

    init_license_var
    init_new_image_var(@observation.when)
    @any_errors = false

    update_permitted_observation_attributes
    @observation.notes = notes_to_sym_and_compact
    warn_if_unchecking_specimen_with_records_present!
    strip_images_if_observation_gps_hidden
    validate_edit_place_name
    detach_removed_images
    try_to_upload_images
    try_to_save_observation_if_there_are_changes

    reload_edit_form and return if @any_errors

    update_project_and_species_list_attachments
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

  def strip_images_if_observation_gps_hidden
    strip_images! if @observation.gps_hidden
  end

  def validate_edit_place_name
    return if validate_place_name(params) && validate_projects(params)

    @any_errors = true
  end

  # As of 2024-06-01, users can remove images right on the edit obs form.
  def detach_removed_images
    new_ids = params[:good_images].split

    # If it didn't make the cut, remove it.
    @observation.images.each do |img|
      next if new_ids.include?(img.id.to_s)

      @observation.remove_image(img)
      img.log_remove_from(@observation)
      flash_notice(:runtime_image_remove_success.t(id: img.id))
    end
  end

  def try_to_upload_images
    @good_images = update_good_images(params[:good_images])
    @bad_images  = create_image_objects(params[:image],
                                        @observation, @good_images)
    attach_good_images(@observation, @good_images)
    @any_errors = true if @bad_images.any?
  end

  def try_to_save_observation_if_there_are_changes
    return unless @dubious_where_reasons == [] && @observation.changed?

    @observation.updated_at = Time.zone.now
    if save_observation(@observation)
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
    init_project_vars
    init_project_vars_for_reload(@observation)
    init_list_vars_for_reload(@observation)
    render(action: :edit)
  end

  def update_project_and_species_list_attachments
    update_projects(@observation, params[:project])
    update_species_lists(@observation, params[:list])
  end

  def update_projects(obs, checks)
    return unless checks

    User.current.projects_member(include: :observations).each do |project|
      before = obs.projects.include?(project)
      after = checks["id_#{project.id}"] == "1"
      next unless before != after

      if after
        project.add_observation(obs)
        flash_notice(:attached_to_project.t(object: :observation,
                                            project: project.title))
      else
        project.remove_observation(obs)
        flash_notice(:removed_from_project.t(object: :observation,
                                             project: project.title))
      end
    end
  end

  def update_species_lists(obs, checks)
    return unless checks

    User.current.all_editable_species_lists.includes(:observations).
      find_each do |list|
      before = obs.species_lists.include?(list)
      after = checks["id_#{list.id}"] == "1"
      next unless before != after

      if after
        list.add_observation(obs)
        flash_notice(:added_to_list.t(list: list.title))
      else
        list.remove_observation(obs)
        flash_notice(:removed_from_list.t(list: list.title))
      end
    end
  end

  def redirect_to_observation_or_create_location
    if @observation.location.nil?
      redirect_with_query(new_location_path(where: @observation.place_name,
                                            set_observation: @observation.id))
    else
      redirect_with_query(permanent_observation_path(@observation.id))
    end
  end
end
