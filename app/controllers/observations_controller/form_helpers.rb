# frozen_string_literal: true

#  :section: Helpers
#
#    create_observation_object(...)     create rough first-drafts.
#
#    save_observation(...)              Save validated objects.
#
#    update_observation_object(...)     Update and save existing objects.
#
#    init_image()                       Handle image uploads.
#    create_image_objects(...)
#    update_good_images(...)
#    attach_good_images(...)

module ObservationsController::FormHelpers
  private

  # NOTE: potential gotcha... Any nested attributes must come last.
  def permitted_observation_args
    [:place_name, :where, :lat, :long, :alt, :when, "when(1i)", "when(2i)",
     "when(3i)", :notes, :specimen, :thumb_image_id, :is_collection_location,
     :gps_hidden]
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
    @licenses = License.current_names_and_ids(@user.license)
  end

  # Initialize image for the dynamic image form at the bottom.
  def init_new_image_var(default_date)
    @new_image = Image.new(when: default_date, license: @user.license,
                           copyright_holder: @user.legal_name)
  end

  def init_specimen_vars
    @collectors_name   = @user.legal_name
    @collectors_number = ""
    @herbarium_name    = @user.preferred_herbarium_name
    @herbarium_id      = ""
  end

  def init_specimen_vars_for_reload
    init_specimen_vars
    if params[:collection_number]
      @collectors_name   = params[:collection_number][:name]
      @collectors_number = params[:collection_number][:number]
    end
    return unless params[:herbarium_record]

    @herbarium_name = params[:herbarium_record][:herbarium_name]
    @herbarium_id   = params[:herbarium_record][:herbarium_id]
  end

  def init_project_vars
    @projects = User.current.projects_member(order: :title,
                                             include: :user_group)
    @project_checks = {}
  end

  def init_project_vars_for_create
    init_project_vars
    @projects.each do |proj|
      @project_checks[proj.id] = (proj.open_membership &&
                                  proj.current?)
    end
  end

  def init_project_vars_for_reload(obs)
    obs.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
    end
    @projects.each do |proj|
      @project_checks[proj.id] = if params[:project].nil?
                                   false
                                 else
                                   params[:project]["id_#{proj.id}"] == "1"
                                 end
    end
  end

  def init_list_vars
    @lists = User.current.all_editable_species_lists.sort_by(&:title)
    @list_checks = {}
  end

  def init_list_vars_for_reload(obs)
    init_list_vars
    @lists = @lists.union(obs.species_lists)
    @lists.each do |list|
      @list_checks[list.id] = param_lookup([:list, "id_#{list.id}"]) == "1"
    end
  end

  ##############################################################################

  # Save observation now that everything is created successfully.
  def save_observation(observation)
    return true if observation.save

    flash_error(:runtime_no_save_observation.t)
    flash_object_errors(observation)
    false
  end

  # Attempt to upload any images.  We will attach them to the observation
  # later, assuming we can create it.  Problem is if anything goes wrong, we
  # cannot repopulate the image forms (security issue associated with giving
  # file upload fields default values).  So we need to do this immediately,
  # even if observation creation fails.  Keep a list of images we've downloaded
  # successfully in @good_images (stored in hidden form field).
  #
  # INPUT: params[:image], observation, good_images (and @user)
  # OUTPUT: list of images we couldn't create
  #
  # cop disabled per https://github.com/MushroomObserver/mushroom-observer/pull/1060#issuecomment-1179410808

  # rubocop:disable Metrics/MethodLength
  def create_image_objects(args, observation, good_images)
    bad_images = []
    if args
      i = 0
      while (args2 = args[i.to_s])
        if (upload = args2[:image]).present?
          if upload.respond_to?(:original_filename)
            name = upload.original_filename.force_encoding("utf-8")
          end
          # image = Image.new(args2) # Rails 3.2
          image = Image.new(args2.permit(permitted_image_args))
          # image = Image.new(args2.permit(:all))
          image.created_at = Time.zone.now
          image.updated_at = image.created_at
          # If image.when is 1950 it means user never saw the form
          # field, so we should use default instead.
          image.when = observation.when if image.when.year == 1950
          image.user = @user
          if !image.save
            bad_images.push(image)
            flash_object_errors(image)
          elsif !image.process_image(strip: observation.gps_hidden)
            name_str = name ? "'#{name}'" : "##{image.id}"
            flash_notice(:runtime_no_upload_image.t(name: name_str))
            bad_images.push(image)
            flash_object_errors(image)
          else
            name = image.original_name
            name = "##{image.id}" if name.empty?
            flash_notice(:runtime_image_uploaded.t(name: name))
            good_images.push(image)
            if observation.thumb_image_id == -i
              observation.thumb_image_id = image.id
            end
          end
        end
        i += 1
      end
    end
    if observation.thumb_image_id && observation.thumb_image_id.to_i <= 0
      observation.thumb_image_id = nil
    end
    bad_images
  end
  # rubocop:enable Metrics/MethodLength

  # List of images that we've successfully downloaded, but which
  # haven't been attached to the observation yet.  Also supports some
  # mininal editing.  INPUT: params[:good_images] (also looks at
  # params[:image_<id>_notes]) OUTPUT: list of images

  def update_good_images(arg)
    # Get list of images first.
    images = (arg || "").split.filter_map do |id|
      Image.safe_find(id.to_i)
    end

    # Now check for edits.
    images.each do |image|
      next unless check_permission(image)

      args = param_lookup([:good_image, image.id.to_s])
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

    images
  end

  # Now that the observation has been successfully created, we can attach
  # any images that were downloaded earlier
  def attach_good_images(observation, images)
    return unless images

    images.each do |image|
      unless observation.image_ids.include?(image.id)
        observation.add_image(image)
        image.log_create_for(observation)
      end
    end
  end

  def strip_images!
    @observation.images.each do |img|
      error = img.strip_gps!
      flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
    end
  end
end
