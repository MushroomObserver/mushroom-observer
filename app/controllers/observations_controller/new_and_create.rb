# frozen_string_literal: true

module ObservationsController::NewAndCreate
  include ObservationsController::FormHelpers
  include ObservationsController::Validators

  # Form to create a new observation, naming, vote, and images.
  # Linked from: left panel
  #
  # Inputs:
  #   params[:observation][...]         observation args
  #   params[:naming][:name]            name
  #   params[:approved_name]            old name
  #   params[:approved_where]           old place name
  #   params[:chosen_name][:name_id]    name radio boxes
  #   params[:naming][:vote][...]       vote args
  #   params[:naming][:reasons][n][...] naming_reasons args
  #   params[:image][n][...]            image args
  #   params[:good_images]              images already downloaded
  #   params[:was_js_on]                was form javascripty? ("yes" = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @what, @names, @valid_names       name validation
  #   @reasons                          array of naming_reasons
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already downloaded
  #

  def new
    # These are needed to create pulldown menus in form.
    init_license_var
    init_new_image_var(Time.zone.now)

    # Clear search list. [Huh? -JPH 20120513]
    clear_query_in_session

    @observation = Observation.new
    @naming      = Naming.new
    @vote        = Vote.new
    @what        = "" # can't be nil else rails tries to call @name.name
    @names       = nil
    @valid_names = nil
    @reasons     = @naming.init_reasons
    @images      = []
    @good_images = []
    @field_code  = params[:field_code]
    init_specimen_vars
    init_project_vars_for_create
    init_list_vars
    defaults_from_last_observation_created
    add_field_slip_project(@field_code)
  end

  ##############################################################################

  private

  def defaults_from_last_observation_created
    # Grab defaults for date and location from last observation the user
    # created if it was less than an hour ago
    # (i.e. if its creation time is larger than one hour ago)
    last_observation = Observation.where(user_id: @user.id).
                       order(:created_at).last
    return unless last_observation && last_observation.created_at > 1.hour.ago

    %w[when where location is_collection_location gps_hidden].each do |attr|
      @observation.send(:"#{attr}=", last_observation.send(attr))
    end

    last_observation.projects.where(open_membership: false).
      find_each do |project|
        next unless project.current?

        @project_checks[project.id] = true
      end

    last_observation.species_lists.each do |list|
      if check_permission(list)
        @lists << list unless @lists.include?(list)
        @list_checks[list.id] = true
      end
    end
  end

  def add_field_slip_project(code)
    project = FieldSlip.find_by(code: code)&.project
    return unless project
    return unless project&.member?(User.current)

    @project_checks[project.id] = true
  end

  ##############################################################################

  public

  def create
    logger.warn("ObservationsController#create: #{Time.zone.now}")
    @observation = create_observation_object(params[:observation])
    logger.warn("create_observation_object: #{Time.zone.now}")
    # set these again, in case they are not defined
    init_license_var
    init_new_image_var(Time.zone.now)

    rough_cut(params)
    logger.warn("rough_cut: #{Time.zone.now}")
    success = true
    success = false unless validate_params(params)
    success = false unless validate_object(@observation)
    success = false unless validate_projects(params)
    success = false if @name && !validate_object(@naming)
    success = false if @name && !@vote.value.nil? && !validate_object(@vote)
    success = false if @bad_images != []
    success = false if success && !save_observation(@observation)
    logger.warn("save_observation: #{Time.zone.now}")
    return reload_new_form(params.dig(:naming, :reasons)) unless success

    @observation.log(:log_observation_created)
    logger.warn("log_observation_created: #{Time.zone.now}")
    save_everything_else(params.dig(:naming, :reasons))
    strip_images! if @observation.gps_hidden
    update_field_slip(@observation, params[:field_code])
    flash_notice(:runtime_observation_success.t(id: @observation.id))
    logger.warn("runtime_observation_success: #{Time.zone.now}")
    redirect_to_next_page
  end

  ##############################################################################

  private

  # Roughly create observation object.  Will validate and save later
  # once we're sure everything is correct.
  # INPUT: params[:observation] (and @user) (and various notes params)
  # OUTPUT: new observation
  def create_observation_object(args)
    now = Time.zone.now
    observation = new_observation(args)
    observation.created_at = now
    observation.updated_at = now
    observation.user       = @user
    observation.name       = Name.unknown
    observation.source     = "mo_website"
    determine_observation_location(observation)
  end

  # NOTE: Call `to_h` on the permitted params if problems with nested params.
  # As of rails 5, params are an ActionController::Parameters object,
  # not a hash.
  def new_observation(args)
    if args
      Observation.new(args.permit(permitted_observation_args).to_h)
    else
      Observation.new
    end
  end

  def determine_observation_location(observation)
    if Location.is_unknown?(observation.place_name) ||
       (observation.lat && observation.lng && observation.place_name.blank?)
      observation.location = Location.unknown
      observation.where = nil
    end
    observation
  end

  def rough_cut(params)
    @observation.notes = notes_to_sym_and_compact
    @naming = Naming.construct({}, @observation)
    @vote = Vote.construct(params.dig(:naming, :vote), @naming)
    @good_images = update_good_images(params[:good_images])
    @bad_images  = create_image_objects(params[:image],
                                        @observation, @good_images)
  end

  def save_everything_else(reason)
    update_naming(reason)
    logger.warn("update_naming: #{Time.zone.now}")
    attach_good_images(@observation, @good_images)
    logger.warn("attach_good_images: #{Time.zone.now}")
    update_projects(@observation, params[:project])
    logger.warn("update_projects: #{Time.zone.now}")
    update_species_lists(@observation, params[:list])
    logger.warn("update_species_lists: #{Time.zone.now}")
    save_collection_number(@observation, params)
    logger.warn("save_collection_number: #{Time.zone.now}")
    save_herbarium_record(@observation, params)
    logger.warn("save_herbarium_record: #{Time.zone.now}")
  end

  def update_naming(reason)
    return unless @name

    @naming.create_reasons(reason, params[:was_js_on] == "yes")
    save_with_log(@naming)
    consensus = ::Observation::NamingConsensus.new(@observation.reload)
    consensus.change_vote(@naming, @vote.value) unless @vote.value.nil?
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
    herbarium, initial_det, accession_number, herbarium_record_notes =
      normalize_herbarium_record_params(obs, params)
    return if not_creating_record?(obs, herbarium, accession_number)

    herbarium_record = lookup_herbarium_record(herbarium, accession_number)
    if !herbarium_record
      herbarium_record = create_herbarium_record(
        herbarium, initial_det, accession_number, herbarium_record_notes
      )
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

  def normalize_herbarium_record_params(obs, params)
    params2   = params[:herbarium_record] || return
    herbarium = params2[:herbarium_name].to_s.strip_html.strip_squeeze
    herbarium = lookup_herbarium(herbarium)
    init_det  = initial_determination(obs)
    accession = params2[:herbarium_id].to_s.strip_html.strip_squeeze
    accession = default_accession_number(obs, params) if accession.blank?
    notes = params2[:herbarium_record_notes]
    [herbarium, init_det, accession, notes]
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

  def initial_determination(obs)
    (obs.name || Name.unknown).text_name
  end

  def default_accession_number(obs, params)
    name, number = normalize_collection_number_params(params)
    number ? "#{name} #{number}" : "MO #{obs.id}"
  end

  def lookup_herbarium_record(herbarium, accession_number)
    HerbariumRecord.where(
      herbarium: herbarium,
      accession_number: accession_number
    ).first
  end

  def create_herbarium_record(herbarium, initial_det, accession_number,
                              herbarium_record_notes)
    HerbariumRecord.create(
      herbarium: herbarium,
      initial_det: initial_det,
      accession_number: accession_number,
      notes: herbarium_record_notes
    )
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

  def redirect_to_next_page
    if @observation.location.nil?
      redirect_to(new_location_path(where: @observation.place_name,
                                    set_observation: @observation.id))
    else
      redirect_to(permanent_observation_path(@observation.id))
    end
  end

  def reload_new_form(reasons)
    @reasons         = @naming.init_reasons(reasons)
    @images          = @bad_images
    @new_image.when  = @observation.when
    @field_code = params[:field_code]
    init_specimen_vars_for_reload
    init_project_vars_for_create
    init_project_vars_for_reload(@observation)
    init_list_vars_for_reload(@observation)
    render(action: :new, location: new_observation_path(q: get_query_param))
  end

  def update_field_slip(observation, field_code)
    field_slip = FieldSlip.find_by(code: field_code)
    return unless field_slip

    field_slip.observation = observation
    field_slip.save
  end
end
