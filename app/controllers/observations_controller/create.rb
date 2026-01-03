# frozen_string_literal: true

module ObservationsController::Create
  include ObservationsController::SharedFormMethods
  include ObservationsController::Validators
  include ::Locationable

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
    create_location_object_if_new(@observation) # may set @location

    @any_errors = false
    validate_name
    validate_place_name
    validate_observation
    validate_projects
    validate_naming if @name
    validate_vote if @name
    validate_images
    try_to_save_location_if_new(@observation)
    try_to_save_new_observation
    return reload_new_form(params.dig(:naming, :reasons)) if @any_errors

    @observation.log(:log_observation_created)

    update_naming(params.dig(:naming, :reasons))
    attach_good_images
    update_projects
    update_species_lists
    save_collection_number
    save_herbarium_record
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

  def try_to_save_new_observation
    return false if @any_errors

    return true if save_observation

    @any_errors = true
    false
  end

  def update_naming(reason)
    return unless @name

    @naming.create_reasons(reason, params[:was_js_on] == "yes")
    save_with_log(@user, @naming)
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
    render(action: :new, location: new_observation_path)
  end

  def update_field_slip
    field_code = params[:field_code]
    field_slip = FieldSlip.find_by(code: field_code)
    return unless field_slip

    field_slip.observation = @observation
    field_slip.save
  end

  def init_location_var_for_reload
    # Preserve the user's place_name input for form re-render
    @default_place_name = @observation.place_name

    # keep location_id if it's -1 (new)
    if @location || @observation.location_id.nil? ||
       @observation.location_id.zero?
      return
    end

    @location = @observation.location
  end
end
