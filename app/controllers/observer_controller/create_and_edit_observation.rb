# frozen_string_literal: true

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
  def create_observation
    # These are needed to create pulldown menus in form.
    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(Time.zone.now)

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
    @observation = Observation.new
    @naming      = Naming.new
    @vote        = Vote.new
    @what        = "" # can't be nil else rails tries to call @name.name
    @names       = nil
    @valid_names = nil
    @reason      = @naming.init_reasons
    @images      = []
    @good_images = []
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

    %w[when where location lat long alt
       is_collection_location gps_hidden].each do |attr|
      @observation.send("#{attr}=", last_observation.send(attr))
    end
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
    success = false if @name && !validate_object(@naming)
    success = false if @name && !@vote.value.nil? && !validate_object(@vote)
    success = false if @bad_images != []
    success = false if success && !save_observation(@observation)

    # Once observation is saved we can save everything else.
    if success
      @observation.log(:log_observation_created)
      save_everything_else(params[:reason]) # should always succeed
      strip_images! if @observation.gps_hidden
      flash_notice(:runtime_observation_success.t(id: @observation.id))
      redirect_to_next_page

    # If anything failed reload the form.
    else
      reload_the_form(params[:reason])
    end
  end

  def rough_cut(params)
    @observation = create_observation_object(params[:observation])
    choose_location_suggestion(@observation)
    @observation.notes = notes_to_sym_and_compact
    @naming      = Naming.construct(params[:naming], @observation)
    @vote        = Vote.construct(params[:vote], @naming)
    @good_images = update_good_images(params[:good_images])
    @bad_images  = create_image_objects(params[:image],
                                        @observation, @good_images)
  end

  def choose_location_suggestion(observation)
    suggested_location = param_lookup([:location_suggestions, :name], "").to_s
    return if suggested_location.blank?

    observation.place_name = suggested_location
  end

  # Symbolize keys; delete key/value pair if value blank
  # Also avoids whitelisting issues
  def notes_to_sym_and_compact
    return Observation.no_notes unless notes_param_present?

    symbolized = params[:observation][:notes].to_unsafe_h.symbolize_keys
    symbolized.delete_if { |_key, value| value.blank? }
  end

  def notes_param_present?
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
    @place_name = @observation.place_name
    @dubious_where_reasons = []
    @location_suggestion_reasons = []
    @location_suggestions = []
    return true if @place_name.present? &&
                   @place_name == params[:approved_where]
    return false if (@place_name.blank? || Location.is_unknown?(@place_name)) &&
                    location_missing
    return false if @observation.location.nil? && location_doesnt_exist
    return false if @observation.location && location_inaccurate?(@observation)

    true
  end

  # Location not given at all.  If geolocation data available, suggest a name
  # for the location based on geolocation info, and suggest existing locations
  # which contain the lat/long given.  If geolocation data not available, gripe
  # about it.  Always return true to tell parent not to create observation
  # yet.  User can still opt to resubmit without changes to override this.
  def location_missing
    @location_suggestion_reasons << :form_observations_location_missing.t
    geo = geolocation(params)
    if geo[:country].present?
      @place_name = Location.geolocation_to_name(geo)
      @location_suggestions = Location.suggestions(@place_name, geo)
      @place_name = Location.user_name(@user, @place_name)
    end
    if geo[:latitude].present?
      @location_suggestions += Location.suggestions_for_latlong(geo[:latitude],
                                                                geo[:longitude])
    end
    true
  end

  # Location doesn't exist.  If we can come up with any suggestions for fixing
  # it, return true to tell parent not to create observation yet, so user has
  # a chance to fix it or choose an existing location.
  def location_doesnt_exist
    db_name = Location.user_name(@user, @place_name)
    @dubious_where_reasons = Location.dubious_name?(db_name, true)
    @location_suggestion_reasons << :form_observations_location_doesnt_exist.t
    @location_suggestions = Location.suggestions(db_name, geolocation(params))
    @dubious_where_reasons.any? || @location_suggestions.any?
  end

  # The user's given Location already exists and could be fine.  However, if
  # geolocation data is available, check if there are more accurate locations
  # available.  If so, return true to tell parent not to create observation
  # yet, so user has a chance to choose one of the more accurate locations.
  def location_inaccurate?(obs)
    return false if obs.lat.blank?

    @location_suggestions = more_accurate_suggestions(obs)
    if @location_suggestions.any?
      @location_suggestion_reasons << :form_observations_location_inaccurate.t
    end
    unless obs.location&.close?(obs.lat, obs.long)
      @location_suggestion_reasons << :form_observations_location_outside.t
    end
    @location_suggestion_reasons.any?
  end

  # Suggest more accurate locations that contain the given lat/long.
  def more_accurate_suggestions(obs)
    close = obs.location&.close?(obs.lat, obs.long)
    # If current location isn't even close, then suggest *any* location that
    # contains the point, otherwise restrict to more accurate locations.
    area = close ? obs.location.pseudoarea : 360*360
    Location.suggestions_for_latlong(obs.lat, obs.long).
      select { |loc| loc.pseudoarea <= area }.
      reject { |loc| loc == obs.location }
  end

  # If user changes the lat/long of an existing observation make sure the
  # new coordinates are still close to the location's bounding box, and
  # suggest some alternatives if not.
  def validate_lat_long_if_changed
    return true unless @observation.lat_changed? || @observation.long_changed?
    return false if @observation.location && location_inaccurate?(@observation)

    true
  end

  def save_everything_else(reason)
    update_naming(reason)
    attach_good_images(@observation, @good_images)
    update_projects(@observation, params[:project])
    update_species_lists(@observation, params[:list])
    save_collection_number(@observation, params)
    save_herbarium_record(@observation, params)
  end

  def save_collection_number(obs, params)
    return unless obs.specimen

    name, number = normalize_collection_number_params(params)
    return unless number

    col_num = CollectionNumber.where(name: name, number: number).first
    if col_num
      flash_warning(:edit_collection_number_already_used.t) if
        col_num.observations.any?
    else
      col_num = CollectionNumber.create(name: name, number: number)
    end
    col_num.add_observation(obs)
  end

  def normalize_collection_number_params(params)
    params2 = params[:collection_number] || return
    name    = params2[:name].to_s.strip_html.strip_squeeze
    number  = params2[:number].to_s.strip_html.strip_squeeze
    name    = @user.legal_name if name.blank?
    number.blank? ? [] : [name, number]
  end

  def save_herbarium_record(obs, params)
    herbarium, initial_det, accession_number =
      normalize_herbarium_record_params(obs, params)
    return if not_creating_record?(obs, herbarium, accession_number)

    herbarium_record = lookup_herbarium_record(herbarium, accession_number)
    if !herbarium_record
      herbarium_record = create_herbarium_record(herbarium, initial_det,
                                                 accession_number)
    elsif herbarium_record.can_edit?
      flash_warning(:create_herbarium_record_already_used.t) if
        herbarium_record.observations.any?
    else
      flash_error(
        :create_herbarium_record_already_used_by_someone_else.t(
          herbarium_name: herbarium.name
        )
      )
      return
    end
    herbarium_record.add_observation(obs)
  end

  def not_creating_record?(obs, herbarium, accession_number)
    return true unless obs.specimen
    # This happens if there is a problem looking up or creating the herbarium.
    return true if !herbarium || accession_number.blank?

    # If user checks specimen box and nothing else, do not create record.
    obs.collection_numbers.empty? &&
      herbarium == @user.preferred_herbarium &&
      params[:herbarium_record][:herbarium_id].blank?
  end

  def normalize_herbarium_record_params(obs, params)
    params2   = params[:herbarium_record] || return
    herbarium = params2[:herbarium_name].to_s.strip_html.strip_squeeze
    herbarium = lookup_herbarium(herbarium)
    init_det  = initial_determination(obs)
    accession = params2[:herbarium_id].to_s.strip_html.strip_squeeze
    accession = default_accession_number(obs, params) if accession.blank?
    [herbarium, init_det, accession]
  end

  def initial_determination(obs)
    (obs.name || Name.unknown).text_name
  end

  def default_accession_number(obs, params)
    name, number = normalize_collection_number_params(params)
    number ? "#{name} #{number}" : "MO #{obs.id}"
  end

  def lookup_herbarium(name)
    return if name.blank?

    name2 = name.sub(/^[^-]* - /, "")
    herbarium = Herbarium.where(name: [name, name2]).first ||
                Herbarium.where(code: name).first
    return herbarium unless herbarium.nil?

    if name != @user.personal_herbarium_name ||
       @user.personal_herbarium
      flash_warning(:create_herbarium_separately.t)
      return nil
    end
    @user.create_personal_herbarium
  end

  def lookup_herbarium_record(herbarium, accession_number)
    HerbariumRecord.where(
      herbarium: herbarium,
      accession_number: accession_number
    ).first
  end

  def create_herbarium_record(herbarium, initial_det, accession_number)
    HerbariumRecord.create(
      herbarium: herbarium,
      initial_det: initial_det,
      accession_number: accession_number
    )
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
  def edit_observation
    pass_query_params
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation

    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(@observation.when)

    # Make sure user owns this observation!
    if !check_permission!(@observation)
      redirect_with_query(action: :show_observation, id: @observation.id)

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
      warn_if_unchecking_specimen_with_records_present!
      strip_images! if @observation.gps_hidden
      any_errors = true unless validate_place_name(params)
      any_errors = true unless validate_lat_long_if_changed

      # Now try to upload images.
      @good_images = update_good_images(params[:good_images])
      @bad_images  = create_image_objects(params[:image],
                                          @observation, @good_images)
      attach_good_images(@observation, @good_images)
      any_errors = true if @bad_images.any?

      # Only save observation if there are changes.
      if @dubious_where_reasons == []
        if @observation.changed?
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
      end

      # Reload form if anything failed.
      if any_errors
        @images         = @bad_images
        @new_image.when = @observation.when
        init_project_vars_for_reload(@observation)
        init_list_vars_for_reload(@observation)
        return
      end

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
        redirect_with_query(action: :show_observation, id: @observation.id)
      end
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

  # Callback to destroy an observation (and associated namings, votes, etc.)
  # Linked from: show_observation
  # Inputs: params[:id] (observation)
  # Redirects to list_observations.
  def destroy_observation
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
  def recalc
    pass_query_params
    id = params[:id].to_s
    begin
      @observation = Observation.find(id)
      @observation.name.display_name
      @observation.calc_consensus
    rescue StandardError => e
      flash_error(:observer_recalc_caught_error.t(error: e))
    end
    # render(plain: "", layout: true)
    redirect_with_query(action: "show_observation", id: id)
  end

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
    observation = Observation.new(args&.permit(whitelisted_observation_args))
    observation.created_at = now
    observation.updated_at = now
    observation.user       = @user
    observation.name       = Name.unknown
    # clear_location(observation) if is_location_unknown?(observation)
    observation
  end

  # I really don't understand what the purpose of this was!
  # def is_location_unknown?(observation)
  #   Location.is_unknown?(observation.place_name) ||
  #     (observation.lat && observation.long && observation.place_name.blank?)
  # end
  #
  # def clear_location(observation)
  #   observation.location = Location.unknown
  #   observation.where = nil
  # end

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
    if params[:herbarium_record]
      @herbarium_name = params[:herbarium_record][:herbarium_name]
      @herbarium_id   = params[:herbarium_record][:herbarium_id]
    end
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
          elsif !image.process_image(observation.gps_hidden)
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

  def hide_thumbnail_map
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

  def strip_images!
    @observation.images.each do |img|
      error = img.strip_gps!
      flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
    end
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

  def update_naming(reason)
    if @name
      @naming.create_reasons(reason, params[:was_js_on] == "yes")
      save_with_log(@naming)
      @observation.reload
      @observation.change_vote(@naming, @vote.value) unless @vote.value.nil?
    end
  end

  def whitelisted_observation_args
    [:place_name, :where, :lat, :long, :alt, :when, "when(1i)", "when(2i)",
     "when(3i)", :notes, :specimen, :thumb_image_id, :is_collection_location,
     :gps_hidden]
  end

  def whitelisted_observation_params
    return unless params[:observation]

    params[:observation].permit(whitelisted_observation_args)
  end

  def geolocation(params)
    {
      country: params[:country],
      state: params[:state],
      county: params[:county],
      city: params[:city],
      latitude: @observation.lat, # already parsed
      longitude: @observation.long
    }
  end
end
