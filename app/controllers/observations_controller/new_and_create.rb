# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::NewAndCreate
  include ObservationsController::FormHelpers
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

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def new
    # These are needed to create pulldown menus in form.
    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(Time.zone.now)

    # Clear search list. [Huh? -JPH 20120513]
    clear_query_in_session

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

  def defaults_from_last_observation_created # rubocop:disable Metrics/AbcSize
    # Grab defaults for date and location from last observation the user
    # created if it was less than an hour ago
    # (i.e. if its creation time is larger than one hour ago)
    last_observation = Observation.where(user_id: @user.id).
                       order(:created_at).last
    return unless last_observation && last_observation.created_at > 1.hour.ago

    %w[when where location is_collection_location gps_hidden].each do |attr|
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

  # cop disabled per https://github.com/MushroomObserver/mushroom-observer/pull/1060#issuecomment-1179410808
  def create # rubocop:disable Metrics/AbcSize
    @observation = create_observation_object(params[:observation])
    # set these again, in case they are not defined
    @licenses = License.current_names_and_ids(@user.license)
    @new_image = init_image(Time.zone.now)

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
      reload_new_form(params[:reason])
    end
  end

  def rough_cut(params)
    @observation.notes = notes_to_sym_and_compact
    @naming = Naming.construct(params[:naming], @observation)
    @vote = Vote.construct(params[:vote], @naming)
    @good_images = update_good_images(params[:good_images])
    @bad_images  = create_image_objects(params[:image],
                                        @observation, @good_images)
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
    notes = params2[:herbarium_record_notes]
    [herbarium, init_det, accession, notes]
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

  def create_herbarium_record(herbarium, initial_det, accession_number,
                              herbarium_record_notes)
    HerbariumRecord.create(
      herbarium: herbarium,
      initial_det: initial_det,
      accession_number: accession_number,
      notes: herbarium_record_notes
    )
  end

  def redirect_to_next_page
    if @observation.location.nil?
      redirect_to(controller: :location,
                  action: :create_location,
                  where: @observation.place_name,
                  set_observation: @observation.id)
    else
      redirect_to(action: :show, id: @observation.id)
    end
  end

  def reload_new_form(reason)
    @reason          = @naming.init_reasons(reason)
    @images          = @bad_images
    @new_image.when  = @observation.when
    init_specimen_vars_for_reload
    init_project_vars_for_reload(@observation)
    init_list_vars_for_reload(@observation)
    render(action: :new)
  end

  ##############################################################################

  private

  # Used by :create
  def update_naming(reason)
    return unless @name

    @naming.create_reasons(reason, params[:was_js_on] == "yes")
    save_with_log(@naming)
    @observation.reload
    @observation.change_vote(@naming, @vote.value) unless @vote.value.nil?
  end
end
