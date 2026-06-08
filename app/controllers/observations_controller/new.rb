# frozen_string_literal: true

module ObservationsController::New
  include ObservationsController::SharedFormMethods
  include ObservationsController::Validators

  # Form to create a new observation, naming, vote, and images.
  # Linked from: left panel
  #
  # Inputs:
  #   params[:observation][...]                   observation args
  #   params[:observation][:naming][:name]        name
  #   params[:observation][:naming][:vote][...]   vote args
  #   params[:observation][:naming][:reasons][...] naming_reasons args
  #   params[:observation][:image][n][...]        image args
  #   params[:observation][:good_image_ids]       images already uploaded
  #   params[:approved_name]                      old name
  #   params[:approved_where]                     old place name
  #   params[:chosen_name][:name_id]              name radio boxes
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
    @field_code        = params[:field_code]
    @field_code_locked = @field_code.present?
    init_specimen_vars
    init_project_vars_for_new
    init_list_vars
    defaults_from_last_observation_created
    add_list(SpeciesList.safe_find(params[:species_list]))
    @observation.when = params[:date] if params[:date]
    add_field_slip_project(@field_code)
    check_location
    render_new_view
  end

  ##############################################################################

  private

  def render_new_view
    render(Views::Controllers::Observations::New.new(**new_view_attrs))
  end

  def new_view_attrs
    new_view_obs_attrs.merge(new_view_naming_attrs).
      merge(new_view_specimen_attrs).merge(new_view_project_attrs).
      merge(field_code: @field_code,
            field_code_locked: @field_code_locked || false,
            q_param: q_param)
  end

  def new_view_obs_attrs
    {
      observation: @observation, user: @user, location: @location,
      good_images: @good_images || [], exif_data: @exif_data || {},
      given_name: @given_name, place_name: @place_name,
      default_place_name: @default_place_name,
      dubious_where_reasons: @dubious_where_reasons
    }
  end

  def new_view_naming_attrs
    {
      vote: @vote, names: @names, valid_names: @valid_names,
      reasons: @reasons,
      suggest_corrections: @suggest_corrections || false,
      parent_deprecated: @parent_deprecated || false
    }
  end

  def new_view_specimen_attrs
    {
      collectors_name: @collectors_name,
      collectors_number: @collectors_number,
      herbarium_name: @herbarium_name, herbarium_id: @herbarium_id,
      accession_number: @accession_number
    }
  end

  def new_view_project_attrs
    {
      projects: @projects || [],
      submitted_project_ids: @submitted_project_ids,
      lists: @lists || [], submitted_list_ids: @submitted_list_ids,
      error_checked_projects: @error_checked_projects || [],
      suspect_checked_projects: @suspect_checked_projects || []
    }
  end

  def init_naming_and_vote
    @naming      = Naming.new
    @vote        = Vote.new
    @given_name = params[:name] || ""
    return unless params[:notes] && params[:notes][:Field_Slip_ID]

    @given_name = params[:notes][:Field_Slip_ID].tr("_", "")
    @vote.value = 3.0
  end

  # `@observation` is a fresh `Observation.new` here, so assigning
  # `project_ids =` stays in-memory until save (Rails' has_many-
  # through `*_ids=` only commits on a persisted parent).
  def init_project_vars_for_new
    init_project_vars
    @observation.project_ids = @projects.select(&:current?).map(&:id)
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

    @observation.project_ids =
      last_observation.projects.find_each.select(&:current?).map(&:id)

    last_observation.species_lists.each do |list|
      add_list(list)
    end
  end

  def add_list(list)
    return unless list && permission?(list)

    @lists << list unless @lists.include?(list)
    ids = @observation.species_list_ids
    @observation.species_list_ids = ids | [list.id]
  end

  # Adding a field-slip project: always check it; for other already-
  # checked projects, keep them checked UNLESS they have their own
  # field_slip_prefix (in which case adding a new field-slip project
  # supersedes them — original ERB had this exclusive behavior).
  def add_field_slip_project(code)
    project = FieldSlip.find_by(code: code)&.project
    return unless project&.current? || project&.admin?(@user)
    return unless project&.member?(@user)

    @projects.append(project) unless @projects.include?(project)
    current_ids = @observation.project_ids
    @observation.project_ids = @projects.select do |proj|
      proj == project ||
        (current_ids.include?(proj.id) && proj.field_slip_prefix.nil?)
    end.map(&:id)
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
