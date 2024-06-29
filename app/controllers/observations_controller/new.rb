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

    # Clear search list. [Huh? -JPH 20120513]
    clear_query_in_session

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
    init_project_vars_for_create
    init_list_vars
    defaults_from_last_observation_created
    add_field_slip_project(@field_code)
  end

  ##############################################################################

  private

  def init_naming_and_vote
    @naming      = Naming.new
    @vote        = Vote.new
    @given_name  = "" # can't be nil else rails tries to call @name.name
    return unless params[:notes] && params[:notes][:Field_Slip_ID]

    @given_name = params[:notes][:Field_Slip_ID].tr("_", "")
    @vote.value = 3.0
  end

  def defaults_from_last_observation_created
    # Grab defaults for date and location from last observation the user
    # created if it was less than an hour ago
    # (i.e. if its creation time is larger than one hour ago)
    last_observation = Observation.where(user_id: @user.id).
                       order(:created_at).last
    return unless last_observation && last_observation.created_at > 1.hour.ago

    %w[when where location_id is_collection_location gps_hidden].each do |attr|
      @observation.send(:"#{attr}=", last_observation.send(attr))
    end

    @project_checks = {}
    last_observation.projects.find_each do |project|
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
end
