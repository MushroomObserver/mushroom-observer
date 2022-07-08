# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::EditAndUpdate
  include ObservationsController::FormHelpers
  #
  # Form to edit an existing observation.
  # Linked from: left panel
  #
  #
  #
  # Inputs:
  #   params[:id]                       observation id
  #   params[:observation][...]         observation args
  #   params[:image][n][...]            image args
  #   params[:log_change][:checked]     log change in RSS feed?
  #
  # Outputs:
  #   @observation                      populated object
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already attached
  #
  def edit
    pass_query_params
    return unless (@observation = find_or_goto_index(
      Observation, params[:id].to_s
    ))

    # Make sure user owns this observation!
    unless check_permission!(@observation)
      redirect_with_query(action: :show, id: @observation.id) and return
    end

    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(@observation.when)

    # Initialize form.
    @images      = []
    @good_images = @observation.images
    init_project_vars_for_edit(@observation)
    init_list_vars_for_edit(@observation)
  end

  def update # rubocop:disable Metrics/AbcSize
    pass_query_params
    return unless (@observation = find_or_goto_index(
      Observation, params[:id].to_s
    ))

    # Make sure user owns this observation!
    unless check_permission!(@observation)
      redirect_with_query(action: :show, id: @observation.id) and return
    end

    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(Time.zone.now)

    any_errors = false
    update_whitelisted_observation_attributes
    @observation.notes = notes_to_sym_and_compact
    warn_if_unchecking_specimen_with_records_present!
    strip_images! if @observation.gps_hidden

    # Validate place name
    @place_name = @observation.place_name
    @dubious_where_reasons = []
    if @place_name != params[:approved_where] && @observation.location.nil?
      db_name = Location.user_name(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
      any_errors = true if @dubious_where_reasons.any?
    end

    # Now try to upload images.
    @good_images = update_good_images(params[:good_images])
    @bad_images  = create_image_objects(params[:image],
                                        @observation, @good_images)
    attach_good_images(@observation, @good_images)
    any_errors = true if @bad_images.any?

    # Only save observation if there are changes.
    if @dubious_where_reasons == [] && @observation.changed?
      @observation.updated_at = Time.zone.now
      if save_observation(@observation)
        id = @observation.id
        flash_notice(:runtime_edit_observation_success.t(id: id))
        touch = (param_lookup([:log_change, :checked]) == "1")
        @observation.log(:log_observation_updated, touch: touch)
      else
        any_errors = true
      end
    end

    # Reload form if anything failed.
    reload_edit_form and return if any_errors

    # Update project and species_list attachments.
    update_projects(@observation, params[:project])
    update_species_lists(@observation, params[:list])

    # Redirect to show_observation or create_location on success.
    if @observation.location.nil?
      redirect_with_query(controller: :location,
                          action: :create_location,
                          where: @observation.place_name,
                          set_observation: @observation.id)
    else
      redirect_with_query(action: :show, id: @observation.id)
    end
  end

  def update_whitelisted_observation_attributes
    @observation.attributes = whitelisted_observation_params || {}
  end

  def warn_if_unchecking_specimen_with_records_present!
    return if @observation.specimen
    return unless @observation.specimen_was

    return if @observation.collection_numbers.empty? &&
              @observation.herbarium_records.empty? &&
              @observation.sequences.empty?

    flash_warning(:edit_observation_turn_off_specimen_with_records_present.t)
  end

  def reload_edit_form
    @images         = @bad_images
    @new_image.when = @observation.when
    init_project_vars_for_reload(@observation)
    init_list_vars_for_reload(@observation)
    render(action: :edit)
  end

  ##############################################################################

  private

  # used by :update, :update_whitelisted_observation_attributes
  def whitelisted_observation_params
    return unless params[:observation]

    params[:observation].permit(whitelisted_observation_args)
  end
end
