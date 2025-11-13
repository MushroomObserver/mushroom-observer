# frozen_string_literal: true

#  :section: Shared form private methods
#
#    permitted_observation_args
#    update_permitted_observation_attributes
#    permitted_observation_params
#    notes_to_sym_and_compact
#    notes_param_present?
#
#    init_license_var
#    init_new_image_var
#    init_specimen_vars
#    init_specimen_vars_for_reload
#    init_project_vars
#    init_project_vars_for_reload
#    init_list_vars
#    init_list_vars_for_reload
#    save_observation
#
#    create_image_objects_and_update_bad_images
#    try_to_save_image
#    update_good_images
#    attach_good_images
#    strip_images!
#
#    update_projects
#    update_species_lists
#
module ObservationsController::SharedFormMethods
  private

  # NOTE: potential gotcha... Any nested attributes must come last.
  def permitted_observation_args
    [:lat, :lng, :alt, :gps_hidden, :place_name, :where, :location_id,
     :is_collection_location, :when, "when(1i)", "when(2i)", "when(3i)",
     :notes, :specimen, :thumb_image_id]
  end

  def update_permitted_observation_attributes
    @observation.attributes = permitted_observation_params || {}
  end

  # NOTE: call `to_h` on the permitted params if problems with nested params.
  # As of rails 5, params are an ActionController::Parameters object,
  # not a hash.
  def permitted_observation_params
    return unless params[:observation]

    params[:observation].permit(permitted_observation_args).to_h
  end

  # Symbolize keys; delete key/value pair if value blank
  # Also avoids param permitting issues
  def notes_to_sym_and_compact
    return Observation.no_notes unless notes_param_present?

    symbolized = params[:observation][:notes].to_unsafe_h.symbolize_keys
    symbolized.compact_blank!
  end

  def notes_param_present?
    params.dig(:observation, :notes).present?
  end

  def init_license_var
    @licenses = License.available_names_and_ids(@user.license)
  end

  # Initialize image for the dynamic image form at the bottom.
  def init_new_image_var(default_date)
    @new_image = Image.new(when: default_date, license: @user.license,
                           copyright_holder: @user.legal_name)
  end

  def init_specimen_vars
    @collectors_name   = params.dig(:notes, :Collector) || @user.legal_name
    @collectors_number = ""
    @herbarium_name    = @user.preferred_herbarium_name
    @herbarium_id      = @user.preferred_herbarium&.id
    @accession_number  = ""
  end

  def init_specimen_vars_for_reload
    init_specimen_vars
    if params[:collection_number]
      @collectors_name   = params[:collection_number][:name]
      @collectors_number = params[:collection_number][:number]
    end
    return unless params[:herbarium_record]

    @herbarium_name   = params[:herbarium_record][:herbarium_name]
    @herbarium_id     = params[:herbarium_record][:herbarium_id]
    @accession_number = params[:herbarium_record][:accession_number]
  end

  def init_project_vars
    @projects = @user.projects_member(order: :title,
                                      include: :user_group)
    @project_checks = {}
  end

  def init_project_vars_for_reload
    @observation.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
    end
    @projects.each do |proj|
      p = params[:project]
      @project_checks[proj.id] = p.nil? ? false : p["id_#{proj.id}"] == "1"
    end
  end

  def init_list_vars
    @lists = @user.all_editable_species_lists.sort_by(&:title)
    @list_checks = {}
  end

  def init_list_vars_for_reload
    init_list_vars
    @lists = @lists.union(@observation.species_lists)
    @lists.each do |list|
      @list_checks[list.id] = params.dig(:list, "id_#{list.id}") == "1"
    end
  end

  # Save observation now that everything is created successfully.
  def save_observation
    return true if @observation.save

    flash_error(:runtime_no_save_observation.t)
    flash_object_errors(@observation)
    false
  end

  ##############################################################################

  # Attempt to upload any images.  We will attach them to the observation
  # later, assuming we can create it.  Problem is if anything goes wrong, we
  # cannot repopulate the image forms (security issue associated with giving
  # file upload fields default values).  So we need to do this immediately,
  # even if observation creation fails.  Keep a list of images we've uploaded
  # successfully in @good_images (stored in hidden form field).
  #
  # INPUT: params[:image], observation, good_images (and @user)
  # OUTPUT: list of images we couldn't create
  #
  def create_image_objects_and_update_bad_images
    @bad_images = []
    # can't do each_with_index here because it's ActionController::Parameters
    params[:image]&.each do |idx, args|
      next if (upload = args[:image]).blank?

      if upload.respond_to?(:original_filename)
        name = upload.original_filename.force_encoding("utf-8")
      end
      image = Image.new(args.permit(permitted_image_args))
      image.created_at = Time.zone.now
      image.updated_at = image.created_at
      # If image.when is 1950 it means user never saw the form
      # field, so we should use default instead.
      image.when = @observation.when if image.when.year == 1950
      image.user = @user
      try_to_save_image(idx.to_i, image, name)
    end
    @observation.thumb_image_id = nil if @observation.thumb_image_id&.<= 0
    @bad_images
  end

  # Try to save a single image.  If successful, add it to good_images.
  def try_to_save_image(idx, image, name)
    if !image.save
      @bad_images.push(image)
      flash_object_errors(image)
    elsif !image.process_image(strip: @observation.gps_hidden)
      name_str = name ? "'#{name}'" : "##{image.id}"
      flash_notice(:runtime_no_upload_image.t(name: name_str))
      @bad_images.push(image)
      flash_object_errors(image)
    else
      name = image.original_name
      name = "##{image.id}" if name.empty?
      flash_notice(:runtime_image_uploaded.t(name: name))
      @good_images.push(image)
      if @observation.thumb_image_id == -idx
        @observation.thumb_image_id = image.id
      end
    end
  end

  # List of images that we've successfully uploaded, but which haven't been
  # attached to the observation yet.  Also supports some mininal editing.
  # INPUT: params[:good_images] (also looks at params[:image_<id>_notes])
  # OUTPUT: list of images

  def update_good_images
    # Get list of images first.
    @good_images = (params[:good_image_ids] || "").split.filter_map do |id|
      Image.safe_find(id.to_i)
    end

    # Now check for edits.
    @good_images.map do |image|
      next unless permission?(image)

      args = params.dig(:good_image, image.id.to_s)
      next unless args

      image.attributes = args.permit(permitted_image_args)
      next unless image.when_changed? ||
                  image.notes_changed? ||
                  image.copyright_holder_changed? ||
                  image.license_id_changed? ||
                  image.original_name_changed?

      image.updated_at = Time.zone.now
      if image.save
        flash_notice(:runtime_image_updated_notes.t(id: image.id))
      else
        flash_object_errors(image)
      end
    end
  end

  # For now, this has to read the exif off the actual file on the server.
  # This is because the exif data is not stored on the Image record.
  def get_exif_data(images)
    data = {}
    images.each do |image|
      # Don't hide GPS for the owner viewing their own edit form
      exif_data = image&.read_exif_geocode(hide_gps: false)
      # If no EXIF data (no GPS), provide basic info from database
      if exif_data.nil?
        exif_data = {
          lat: nil,
          lng: nil,
          alt: nil,
          date: image.when&.strftime("%d-%B-%Y"),
          file_name: image.original_name,
          file_size: nil # Could calculate from file system if needed
        }
      else
        # EXIF data exists, but ensure file_name is set from database
        exif_data[:file_name] ||= image.original_name
      end
      data[image.id] = exif_data
    end
    data
  end

  # Now that the observation has been successfully created, we can attach
  # any images that were uploaded earlier
  def attach_good_images
    return unless @good_images

    @good_images.each do |image|
      unless @observation.image_ids.include?(image.id)
        @observation.add_image(image)
        image.log_create_for(@observation)
      end
    end
  end

  def strip_images!
    @observation.images.each do |img|
      error = img.strip_gps!
      flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
    end
  end

  ##############################################################################

  def update_projects
    return unless (checks = params[:project])

    @user.projects_member(include: :observations).each do |project|
      before = @observation.projects.include?(project)
      after = checks["id_#{project.id}"] == "1"
      next unless before != after

      if after
        project.add_observation(@observation)
        name_flash_for_project(@observation.name, project)
      else
        project.remove_observation(@observation)
        flash_notice(:removed_from_project.t(object: :observation,
                                             project: project.title))
      end
    end
  end

  def update_species_lists
    return unless (checks = params[:list])

    @user.all_editable_species_lists.includes(:observations).
      find_each do |list|
      before = @observation.species_lists.include?(list)
      after = checks["id_#{list.id}"] == "1"
      next unless before != after

      if after
        list.add_observation(@observation)
        flash_notice(:added_to_list.t(list: list.title))
      else
        list.remove_observation(@observation)
        flash_notice(:removed_from_list.t(list: list.title))
      end
    end
  end
end
