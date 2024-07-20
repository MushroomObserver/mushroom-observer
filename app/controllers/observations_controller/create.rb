# frozen_string_literal: true

module ObservationsController::Create
  include ObservationsController::SharedFormMethods
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
  #   params[:good_image_ids]           images already uploaded
  #   params[:was_js_on]                was form javascripty? ("yes" = true)
  #
  # Outputs:
  #   @observation, @naming, @vote      empty objects
  #   @given_name, @names, @valid_names name validation
  #   @reasons                          array of naming_reasons
  #   @images                           array of images
  #   @licenses                         used for image license menu
  #   @new_image                        blank image object
  #   @good_images                      list of images already uploaded
  #

  def create
    # Create a bare observation
    @observation = create_observation_object(params[:observation])
    # Set license/image defaults again, in case they are not defined
    init_license_var
    init_new_image_var(Time.zone.now)

    rough_cut
    rough_cut_new_location_if_requested # may set @location
    success = true
    success = false unless validate_name
    success = false unless validate_place_name # if there is no id
    success = false unless validate_object(@observation)
    success = false unless validate_projects
    success = false if @name && !validate_object(@naming)
    success = false if @name && !@vote.value.nil? && !validate_object(@vote)
    success = false if @bad_images != []
    success = false if success && @location && !save_location
    success = false if success && !save_observation
    return reload_new_form(params.dig(:naming, :reasons)) unless success

    @observation.log(:log_observation_created)
    save_everything_else(params.dig(:naming, :reasons))
    strip_images! if @observation.gps_hidden
    update_field_slip
    flash_notice(:runtime_observation_success.t(id: @observation.id))
    redirect_to_next_page
  end

  ##############################################################################

  private

  # Roughly create observation object.  Will validate and save later
  # once we're sure everything is correct.
  # INPUT: params[:observation] (and @user) (and various notes params)
  # OUTPUT: new observation
  # NOTE: Call `to_h` on the permitted params if problems with nested params.
  # As of rails 5, params are ActionController::Parameters object, not hash.
  def create_observation_object(args = {})
    args = args&.permit(permitted_observation_args).to_h
    now = Time.zone.now
    Observation.new(args&.merge({ created_at: now,
                                  updated_at: now,
                                  user: @user,
                                  name: Name.unknown,
                                  source: "mo_website" }))
  end

  def rough_cut
    @observation.notes = notes_to_sym_and_compact
    @naming = Naming.construct({}, @observation)
    @vote = Vote.construct(params.dig(:naming, :vote), @naming)
    update_good_images
    @exif_data = get_exif_data(@good_images) # in case of form reload
    create_image_objects_and_update_bad_images
  end

  # We now have an @observation, and maybe a "-1" location_id, indicating a
  # new Location (if accompanied by bounding box lat/lng). If everything is
  # present, create a new @location, and associate it with the @observation
  def rough_cut_new_location_if_requested
    # Ensure we have the minimum necessary to create a new location
    unless @observation.location_id == -1 &&
           (place_name = params.dig(:observation, :place_name)).present? &&
           (north = params.dig(:location, :north)).present? &&
           (south = params.dig(:location, :south)).present? &&
           (east = params.dig(:location, :east)).present? &&
           (west = params.dig(:location, :west)).present?
      return false
    end

    # Ignore hidden attribute even if the obs is hidden, because saving a
    # Location with `hidden: true` fuzzes the lat/lng bounds unpredictably.
    attributes = { hidden: false, user_id: @user.id,
                   north:, south:, east:, west: }
    # Add optional attributes. :notes not implemented yet.
    [:high, :low, :notes].each do |key|
      if (val = params.dig(:location, key)).present?
        attributes[key] = val
      end
    end

    @location = Location.new(attributes)
    # With a Location instance, we can use the `display_name=` setter method,
    # which figures out scientific/postal format of user input and sets
    # location `name` and `scientific_name` accordingly.
    @location.display_name = place_name
  end

  # The form may be in a state where it has an existing MO Location name in the
  # `place_name` field, but not the corresponding MO location_id. It could be
  # because of user trying to create a duplicate, or because the user had a
  # prefilled location, but clicked on the "Create Location" button - this keeps
  # the place_name, but clears the location_id field. Either way, we need to
  # check if we already have a location by this name. If so, find the existing
  # location and use that for the obs.
  def validate_place_name
    place_name = @observation.place_name
    lat = @observation.lat
    lng = @observation.lng
    return false if !lat && !lng && place_name.blank?

    # Set location to unknown if place_name blank && lat/lng are present
    if Location.is_unknown?(place_name) || (lat && lng && place_name.blank?)
      @observation.location = Location.unknown
      @observation.where = nil
      # If it's unknown, we don't need to check for duplicates.
      return true
    end

    name = Location.user_format(@user, place_name)
    # can't use Location.location_exists?, true for undefined where strings
    if (location = Location.find_by(name: name))
      @observation.location_id = location.id
      return true
    end

    @dubious_where_reasons = Location.dubious_name?(name, true)
    @dubious_where_reasons.empty?
  end

  def save_location
    if save_with_log(@location)
      # Associate the location with the observation
      @observation.location_id = @location.id
      true
    else
      # Failed to create location
      flash_object_errors(@location)
      false
    end
  end

  def save_everything_else(reason)
    update_naming(reason)
    attach_good_images
    update_projects
    update_species_lists
    save_collection_number
    save_herbarium_record
  end

  def update_naming(reason)
    return unless @name

    @naming.create_reasons(reason, params[:was_js_on] == "yes")
    save_with_log(@naming)
    consensus = ::Observation::NamingConsensus.new(@observation.reload)
    consensus.change_vote(@naming, @vote.value) unless @vote.value.nil?
  end

  def save_collection_number
    return unless @observation.specimen

    name, number = normalize_collection_number_params
    return unless number

    col_num = CollectionNumber.where(name: name, number: number).first
    if col_num
      flash_warning(:edit_collection_number_already_used.t) if
        col_num.observations.any?
    else
      col_num = CollectionNumber.create(name: name, number: number)
    end
    col_num.add_observation(@observation)
  end

  def normalize_collection_number_params
    params2 = params[:collection_number] || return
    name    = params2[:name].to_s.strip_html.strip_squeeze
    number  = params2[:number].to_s.strip_html.strip_squeeze
    name    = @user.legal_name if name.blank?
    number.blank? ? [] : [name, number]
  end

  def save_herbarium_record
    herbarium, initial_det, accession_number, herbarium_record_notes =
      normalize_herbarium_record_params
    return if not_creating_record?(herbarium, accession_number)

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
    herbarium_record.add_observation(@observation)
  end

  def normalize_herbarium_record_params
    params2   = params[:herbarium_record] || return
    herbarium = params2[:herbarium_name].to_s.strip_html.strip_squeeze
    herbarium = lookup_herbarium(herbarium)
    init_det  = initial_determination
    accession = params2[:accession_number].to_s.strip_html.strip_squeeze
    accession = default_accession_number if accession.blank?
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

  def initial_determination
    (@observation.name || Name.unknown).text_name
  end

  def default_accession_number
    name, number = normalize_collection_number_params
    number ? "#{name} #{number}" : "MO #{@observation.id}"
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

  def not_creating_record?(herbarium, accession_number)
    return true unless @observation.specimen
    # This happens if there is a problem looking up or creating the herbarium.
    return true if !herbarium || accession_number.blank?

    # If user checks specimen box and nothing else, do not create record.
    @observation.collection_numbers.empty? &&
      herbarium == @user.preferred_herbarium &&
      params[:herbarium_record][:accession_number].blank?
  end

  def redirect_to_next_page
    if @observation.location_id.nil?
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
    @field_code      = params[:field_code]
    init_location_var_for_reload
    init_specimen_vars_for_reload
    init_project_vars
    init_project_vars_for_reload
    init_list_vars_for_reload
    render(action: :new, location: new_observation_path(q: get_query_param))
  end

  def update_field_slip
    field_code = params[:field_code]
    field_slip = FieldSlip.find_by(code: field_code)
    return unless field_slip

    field_slip.observation = @observation
    field_slip.save
  end

  def init_location_var_for_reload
    return if @location || !@observation.location_id

    @location = @observation.location
  end
end
