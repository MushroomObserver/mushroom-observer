# encoding: utf-8
# see observer_controller.rb
class ObserverController
  # Form to create a new observation, naming, vote, and images.
  # Linked from: left panel
  #
  # Inputs:
  #   params[:observation][...]         observation args
  #   params[:name][:name]              name
  #   params[:approved_name]            old name
  #   params[:approved_where]           old place name
  #   params[:chosen_name][:name_id]    name radio boxes
  #   params[:vote][...]                vote args
  #   params[:reason][n][...]           naming_reason args
  #   params[:image][n][...]            image args
  #   params[:good_images]              images already downloaded
  #   params[:was_js_on]                was form javascripty? ("yes" = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @what, @names, @valid_names       name validation
  #   @reason                           array of naming_reasons
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already downloaded
  #
  def create_observation # :prefetch: :norobots:
    # These are needed to create pulldown menus in form.
    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(Time.now)

    # Clear search list. [Huh? -JPH 20120513]
    clear_query_in_session

    # Create empty instances first time through.
    if request.method != "POST"
      create_observation_get
    else
      create_observation_post(params)
    end
  end

  def create_observation_get
    @observation     = Observation.new
    @naming          = Naming.new
    @vote            = Vote.new
    @what            = "" # can't be nil else rails tries to call @name.name
    @names           = nil
    @valid_names     = nil
    @reason          = @naming.init_reasons
    @images          = []
    @good_images     = []
    init_specimen_vars_for_create
    init_project_vars_for_create
    init_list_vars_for_create
    defaults_from_last_observation_created
  end

  def defaults_from_last_observation_created
    # Grab defaults for date and location from last observation the user
    # created if it was less than an hour ago
    # (i.e. if its creation time is larger than one hour ago)
    last_observation = Observation.where(user_id: @user.id).
                       order(:created_at).last
    return unless last_observation && last_observation.created_at > 1.hour.ago
    @observation.when     = last_observation.when
    @observation.where    = last_observation.where
    @observation.location = last_observation.location
    @observation.lat      = last_observation.lat
    @observation.long     = last_observation.long
    @observation.alt      = last_observation.alt
    last_observation.projects.each do |project|
      @project_checks[project.id] = true
    end
    last_observation.species_lists.each do |list|
      if check_permission(list)
        @lists << list unless @lists.include?(list)
        @list_checks[list.id] = true
      end
    end
  end

  def create_observation_post(params)
    rough_cut(params)
    success = true
    success = false unless validate_name(params)
    success = false unless validate_place_name(params)
    success = false unless validate_object(@observation)
    success = false unless validate_specimen(params)
    success = false if @name && !validate_object(@naming)
    success = false if @name && !validate_object(@vote)
    success = false if @bad_images != []
    success = false if success && !save_observation(@observation)

    # Once observation is saved we can save everything else.
    if success
      save_everything_else(params[:reason]) # should always succeed
      flash_notice(:runtime_observation_success.t(id: @observation.id))
      @observation.log(:log_observation_created_at)
      redirect_to_next_page

    # If anything failed reload the form.
    else
      reload_the_form(params[:reason])
    end
  end

  def rough_cut(params)
    # Create everything roughly first.
    @observation = create_observation_object(params[:observation])
    @observation.notes = notes_to_sym_and_compact
    @naming      = Naming.construct(params[:naming], @observation)
    @vote        = Vote.construct(params[:vote], @naming)
    @good_images = update_good_images(params[:good_images])
    @bad_images  = create_image_objects(params[:image],
                                        @observation, @good_images)
  end

  # Symbolize keys; delete key/value pair if value blank
  # Also avoids whitelisting issues
  def notes_to_sym_and_compact
    return Observation.no_notes unless notes_param?
    symbolized = params[:observation][:notes].to_hash.symbolize_keys
    symbolized.delete_if { |_key, value| value.nil? || value.empty? }
  end

  def notes_param?
    params[:observation] && params[:observation][:notes].present?
  end

  def validate_name(params)
    given_name = param_lookup([:name, :name], "").to_s
    chosen_name = param_lookup([:chosen_name, :name_id], "").to_s
    (success, @what, @name, @names, @valid_names, @parent_deprecated,
     @suggest_corrections) =
      Name.resolve_name(given_name, params[:approved_name], chosen_name)
    @naming.name = @name if @name
    success
  end

  def validate_place_name(params)
    success = true
    @place_name = @observation.place_name
    @dubious_where_reasons = []
    if @place_name != params[:approved_where] && @observation.location.nil?
      db_name = Location.user_name(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
      success = false if @dubious_where_reasons != []
    end
    success
  end

  def validate_specimen(params)
    success = true
    if params[:specimen]
      herbarium_name = params[:specimen][:herbarium_name]
      if herbarium_name
        herbarium_name = herbarium_name.strip_html
        herbarium = Herbarium.where(name: herbarium_name)[0]
        if herbarium
          herbarium_label = herbarium_label_from_params(params)
          success = herbarium.label_free?(herbarium_label)
          duplicate_error(herbarium_name, herbarium_label) unless success
        end
      end
    end
    success
  end

  def duplicate_error(name, label)
    err = :edit_herbarium_duplicate_label.t(herbarium_name: name,
                                            herbarium_label: label)
    flash_error(err)
  end

  def herbarium_label_from_params(params)
    Herbarium.default_specimen_label(params[:name][:name],
                                     params[:specimen][:herbarium_id])
  end

  def save_everything_else(reason)
    if @name
      @naming.create_reasons(reason, params[:was_js_on] == "yes")
      save_with_log(@naming)
      @observation.reload
      @observation.change_vote(@naming, @vote.value)
    end
    attach_good_images(@observation, @good_images)
    update_projects(@observation, params[:project])
    update_species_lists(@observation, params[:list])
    save_specimen(@observation, params)
  end

  def save_specimen(obs, params)
    return unless params[:specimen] && obs.specimen
    herbarium_name = params[:specimen][:herbarium_name]
    return unless herbarium_name && !herbarium_name.empty?
    if params[:specimen][:herbarium_id] == ""
      params[:specimen][:herbarium_id] = obs.id.to_s
    end
    herbarium_label = herbarium_label_from_params(params)
    herbarium = Herbarium.where(name: herbarium_name)[0]
    if herbarium.nil?
      herbarium = Herbarium.new(name: herbarium_name, email: @user.email)
      if herbarium_name == @user.personal_herbarium_name
        herbarium.personal_user = @user
      end
      herbarium.curators.push(@user)
      herbarium.save
    end
    specimen = Specimen.new(herbarium: herbarium,
                            herbarium_label: herbarium_label,
                            user: @user,
                            when: obs.when)
    specimen.save
    specimen.add_observation(obs)
  end

  def redirect_to_next_page
    if @observation.location.nil?
      redirect_to(controller: "location",
                  action: "create_location",
                  where: @observation.place_name,
                  set_observation: @observation.id)
    elsif unshown_notifications?(@user, :naming)
      redirect_to(action: "show_notifications", id: @observation.id)
    else
      redirect_to(action: "show_observation", id: @observation.id)
    end
  end

  def reload_the_form(reason)
    @reason          = @naming.init_reasons(reason)
    @images          = @bad_images
    @new_image.when  = @observation.when
    init_specimen_vars_for_reload
    init_project_vars_for_reload(@observation)
    init_list_vars_for_reload(@observation)
  end

  # Form to edit an existing observation.
  # Linked from: left panel
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
  def edit_observation # :prefetch: :norobots:
    pass_query_params
    includes = [:name, :images, :location]
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation
    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(@observation.when)

    # Make sure user owns this observation!
    if !check_permission!(@observation)
      redirect_with_query(action: "show_observation",
                          id: @observation.id)

      # Initialize form.
    elsif request.method != "POST"
      @images      = []
      @good_images = @observation.images
      init_project_vars_for_edit(@observation)
      init_list_vars_for_edit(@observation)

    else
      any_errors = false

      update_whitelisted_observation_attributes
      @observation.notes = notes_to_sym_and_compact
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
      if @dubious_where_reasons == []
        if @observation.changed?
          @observation.updated_at = Time.now
          if save_observation(@observation)
            id = @observation.id
            flash_notice(:runtime_edit_observation_success.t(id: id))
            touch = (param_lookup([:log_change, :checked]) == "1")
            @observation.log(:log_observation_updated, touch: touch)
          else
            any_errors = true
          end
        end
      end

      # Update project and species_list attachments.
      update_projects(@observation, params[:project])
      update_species_lists(@observation, params[:list])

      # Reload form if anything failed.
      if any_errors
        @images         = @bad_images
        @new_image.when = @observation.when
        init_project_vars_for_reload(@observation)
        init_list_vars_for_reload(@observation)

        # Redirect to show_observation or create_location on success.
      elsif @observation.location.nil?
        redirect_with_query(controller: "location",
                            action: "create_location",
                            where: @observation.place_name,
                            set_observation: @observation.id)
      else
        redirect_with_query(action: "show_observation",
                            id: @observation.id)
      end
    end
  end

  def update_whitelisted_observation_attributes
    @observation.attributes = whitelisted_observation_params || {}
  end

  # Callback to destroy an observation (and associated namings, votes, etc.)
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Redirects to list_observations.
  def destroy_observation # :norobots:
    param_id = params[:id].to_s
    return unless (@observation = find_or_goto_index(Observation, param_id))
    obs_id = @observation.id
    next_state = nil
    # decide where to redirect after deleting observation
    if (this_state = find_query(:Observation))
      this_state.current = @observation
      next_state = this_state.next
    end

    if !check_permission!(@observation)
      flash_error(:runtime_destroy_observation_denied.t(id: obs_id))
      redirect_to(add_query_param({ action: "show_observation", id: obs_id },
                                  this_state))
    elsif !@observation.destroy
      flash_error(:runtime_destroy_observation_failed.t(id: obs_id))
      redirect_to(add_query_param({ action: "show_observation", id: obs_id },
                                  this_state))
    else
      flash_notice(:runtime_destroy_observation_success.t(id: param_id))
      if next_state
        redirect_to(add_query_param({ action: "show_observation",
                                      id: next_state.current_id },
                                    next_state))
      else
        redirect_to(action: "list_observations")
      end
    end
  end

  # I'm tired of tweaking show_observation to call calc_consensus for
  # debugging.  I'll just leave this stupid action in and have it
  # forward to show_observation.
  def recalc # :root: :norobots:
    pass_query_params
    id = params[:id].to_s
    begin
      @observation = Observation.find(id)
      display_name = @observation.name.display_name
      text = @observation.calc_consensus(true)
    rescue => err
      flash_error(:observer_recalc_caught_error.t(error: err))
    end
    # render(text: "", layout: true)
    redirect_with_query(action: "show_observation", id: id)
  end

  ##############################################################################
  #
  #  :section: helpers
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
    now = Time.now
    if args
      observation = Observation.new(args.permit(whitelisted_observation_args))
    else
      observation = Observation.new
    end
    observation.created_at = now
    observation.updated_at = now
    observation.user = @user
    observation.name = Name.unknown
    if Location.is_unknown?(observation.place_name) ||
       (observation.lat && observation.long && observation.place_name.blank?)
      observation.location = Location.unknown
      observation.where = nil
    end
    observation
  end

  def init_specimen_vars_for_create
    @herbarium_name = @user.preferred_herbarium_name
    @herbarium_id = ""
  end

  def init_specimen_vars_for_reload
    @herbarium_name, @herbarium_id =
      if (specimen = params[:specimen])
        [specimen[:herbarium_name], specimen[:herbarium_id]]
      else
        [@user.preferred_herbarium_name, ""]
      end
  end

  def init_project_vars
    @projects = User.current.projects_member.sort_by(&:title)
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
    User.current.projects_member.each do |project|
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
    User.current.all_editable_species_lists.each do |list|
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
        unless (upload = args2[:image]).blank?
          if upload.respond_to?(:original_filename)
            name = upload.original_filename.force_encoding("utf-8")
          end
          # image = Image.new(args2) # Rails 3.2
          image = Image.new(args2.permit(whitelisted_image_args))
          # image = Image.new(args2.permit(:all))
          image.created_at = Time.now
          image.updated_at = image.created_at
          # If image.when is 1950 it means user never saw the form
          # field, so we should use default instead.
          image.when = observation.when if image.when.year == 1950
          image.user = @user
          if !image.save
            bad_images.push(image)
            flash_object_errors(image)
          elsif !image.process_image
            logger.error("Unable to upload image")
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
      image.updated_at = Time.now
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
        observation.log_create_image(image)
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

  def hide_thumbnail_map # :nologin:
    pass_query_params
    id = params[:id].to_s
    if @user
      @user.update_attribute(:thumbnail_maps, false)
      flash_notice(:show_observation_thumbnail_map_hidden.t)
    else
      session[:hide_thumbnail_maps] = true
    end
    redirect_with_query(action: :show_observation, id: id)
  end

  ##############################################################################
  #
  #  Methods relating to User#notes_template
  #
  ##############################################################################

  def use_notes_template?
    @user.notes_template? && @observation.notes.blank?
  end

  # String combining the note parts defined in the User's notes_template
  # with their filled-in values, ignoring parts with blank values
  def combined_notes_parts
    @user.notes_template_parts.each_with_object("") do |part, notes|
      key   = Observation.notes_part_id(part).to_sym
      value = params[key]
      notes << "#{part}: #{value}\n" if value.present?
    end
  end

  ##############################################################################

  private

  def whitelisted_observation_args
    [:place_name, :where, :lat, :long, :alt, :when, "when(1i)", "when(2i)",
     "when(3i)", :notes, :specimen, :thumb_image_id, :is_collection_location]
  end

  def whitelisted_observation_params
    return unless params[:observation]
    params[:observation].permit(whitelisted_observation_args)
  end
end
