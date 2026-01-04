# frozen_string_literal: true

module ObservationsController::New
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

  def new
    # These are needed to create pulldown menus in form.
    init_license_var
    init_new_image_var(Time.zone.now)

    @observation = Observation.new
    if params[:notes]
      @observation.notes = params[:notes].to_unsafe_h.symbolize_keys
    end
    @observation.place_name = params[:place_name]
    init_naming_and_vote
    @names       = nil
    @valid_names = nil
    @reasons     = @naming.init_reasons
    @images      = []
    @good_images = []
    @field_code  = params[:field_code]
    init_specimen_vars
    init_project_vars_for_new
    init_list_vars
    defaults_from_last_observation_created
    add_list(SpeciesList.safe_find(params[:species_list]))
    @observation.when = params[:date] if params[:date]
    add_field_slip_project(@field_code)
    check_location
  end

  ##############################################################################

  private

  def init_naming_and_vote
    @naming      = Naming.new
    @vote        = Vote.new
    @given_name = params[:name] || ""
    return unless params[:notes] && params[:notes][:Field_Slip_ID]

    @given_name = params[:notes][:Field_Slip_ID].tr("_", "")
    @vote.value = 3.0
  end

  def init_project_vars_for_new
    init_project_vars
    @projects.each do |proj|
      @project_checks[proj.id] = proj.current?
    end
  end

  def defaults_from_last_observation_created
    # Grab defaults from last observation the user created.
    # Only grab "when" if was created at most an hour ago.
    last_observation = Observation.recent_by_user(@user).last
    return unless last_observation

    %w[where location_id is_collection_location gps_hidden].each do |attr|
      @observation.send(:"#{attr}=", last_observation.send(attr))
    end
    @location = @observation.location

    if last_observation.created_at > 1.hour.ago
      @observation.when = last_observation.when
    end

    @project_checks = {}
    last_observation.projects.find_each do |project|
      next unless project.current?

      @project_checks[project.id] = true
    end

    last_observation.species_lists.each do |list|
      add_list(list)
    end
  end

  def add_list(list)
    return unless list && permission?(list)

    @lists << list unless @lists.include?(list)
    @list_checks[list.id] = true
  end

  def add_field_slip_project(code)
    project = FieldSlip.find_by(code: code)&.project
    return unless project&.current? || project&.admin?(@user)
    return unless project&.member?(@user)

    @projects.append(project) unless @projects.include?(project)
    @projects.each do |proj|
      @project_checks[proj.id] = (proj == project) ||
                                 (@project_checks[proj.id] &&
                                  proj.field_slip_prefix.nil?)
    end
  end

  def check_location
    if params[:place_name]
      # Cannot use @place_name since that's being used for approved_where
      @default_place_name = params[:place_name]
      loc = Location.place_name_to_location(@default_place_name)
      @location = loc if loc
    else
      @default_place_name = @observation.place_name
    end
  end
end
