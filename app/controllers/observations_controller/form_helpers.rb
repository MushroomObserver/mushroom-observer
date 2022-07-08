# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::FormHelpers
  ##############################################################################
  #
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
  #
  ##############################################################################

  # Roughly create observation object.  Will validate and save later
  # once we're sure everything is correct.
  # INPUT: params[:observation] (and @user) (and various notes params)
  # OUTPUT: new observation
  def create_observation_object(args)
    now = Time.zone.now
    observation = if args
                    Observation.new(args.permit(whitelisted_observation_args))
                  else
                    Observation.new
                  end
    observation.created_at = now
    observation.updated_at = now
    observation.user       = @user
    observation.name       = Name.unknown
    if Location.is_unknown?(observation.place_name) ||
       (observation.lat && observation.long && observation.place_name.blank?)
      observation.location = Location.unknown
      observation.where = nil
    end
    observation
  end

  def init_specimen_vars_for_create
    @collectors_name   = @user.legal_name
    @collectors_number = ""
    @herbarium_name    = @user.preferred_herbarium_name
    @herbarium_id      = ""
  end

  def init_specimen_vars_for_reload
    init_specimen_vars_for_create
    if params[:collection_number]
      @collectors_name   = params[:collection_number][:name]
      @collectors_number = params[:collection_number][:number]
    end
    return unless params[:herbarium_record]

    @herbarium_name = params[:herbarium_record][:herbarium_name]
    @herbarium_id   = params[:herbarium_record][:herbarium_id]
  end

  def init_project_vars
    @projects = User.current.projects_member(order: :title)
    @project_checks = {}
  end

  def init_project_vars_for_create
    init_project_vars
  end

  def init_project_vars_for_edit(obs)
    init_project_vars
    obs.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
      @project_checks[proj.id] = true
    end
  end

  def init_project_vars_for_reload(obs)
    init_project_vars
    obs.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
    end
    @projects.each do |proj|
      p = params[:project]
      @project_checks[proj.id] = p.nil? ? false : p["id_#{proj.id}"] == "1"
    end
  end

  def init_list_vars
    @lists = User.current.all_editable_species_lists.sort_by(&:title)
    @list_checks = {}
  end

  def init_list_vars_for_create
    init_list_vars
  end

  def init_list_vars_for_edit(obs)
    init_list_vars
    obs.species_lists.each do |list|
      @lists << list unless @lists.include?(list)
      @list_checks[list.id] = true
    end
  end

  def init_list_vars_for_reload(obs)
    init_list_vars
    obs.species_lists.each do |list|
      @lists << list unless @lists.include?(list)
    end
    @lists.each do |list|
      @list_checks[list.id] = param_lookup([:list, "id_#{list.id}"]) == "1"
    end
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
         each do |list|
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
          image = Image.new(args2.permit(whitelisted_image_args))
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

  # List of images that we've successfully downloaded, but which
  # haven't been attached to the observation yet.  Also supports some
  # mininal editing.  INPUT: params[:good_images] (also looks at
  # params[:image_<id>_notes]) OUTPUT: list of images
  def update_good_images(arg)
    # Get list of images first.
    images = (arg || "").split(" ").map do |id|
      Image.safe_find(id.to_i)
    end.reject(&:nil?)

    # Now check for edits.
    images.each do |image|
      next unless check_permission(image)

      args = param_lookup([:good_image, image.id.to_s])
      next unless args

      image.attributes = args.permit(whitelisted_image_args)
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

  # Initialize image for the dynamic image form at the bottom.
  def init_image(default_date)
    image = Image.new
    image.when             = default_date
    image.license          = @user.license
    image.copyright_holder = @user.legal_name
    image
  end

  def strip_images!
    @observation.images.each do |img|
      error = img.strip_gps!
      flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
    end
  end

  ##############################################################################

  private

  # can be in helpers
  def whitelisted_observation_args
    [:place_name, :where, :lat, :long, :alt, :when, "when(1i)", "when(2i)",
     "when(3i)", :notes, :specimen, :thumb_image_id, :is_collection_location,
     :gps_hidden]
  end
end
