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
      @observation.notes = NotesHash.from_params(params[:notes]).to_h
    end
    @observation.current_user = @user
    @observation.place_name = params[:place_name]
    @observation.collector = params[:collector].presence || default_collector
    init_naming_and_vote
    @names       = nil
    @valid_names = nil
    @reasons     = @naming.init_reasons
    @images      = []
    @good_images = []
    @field_code = params[:field_code]
    init_specimen_vars
    init_project_vars_for_new
    init_list_vars
    defaults_from_last_observation_created
    # Must follow defaults_from_last_observation_created, which copies the
    # user's last observation's location unconditionally.
    apply_field_slip_location(@field_code)
    add_list(SpeciesList.safe_find(params[:species_list]))
    @observation.when = params[:date] if params[:date]
    add_field_slip_project(@field_code)
    check_location
    render_new_view
  end

  ##############################################################################

  private

  def render_new_view(status: :ok, **render_opts)
    render(Views::Controllers::Observations::New.new(**new_view_attrs),
           status: status, **render_opts)
  end

  def new_view_attrs
    new_view_obs_attrs.merge(new_view_naming_attrs).
      merge(new_view_specimen_attrs).merge(new_view_project_attrs).
      merge(field_code: @field_code)
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
      suspect_checked_projects: @suspect_checked_projects || [],
      cross_prefix_projects: @cross_prefix_projects || [],
      slip_target_project: @slip_target_project
    }
  end

  # Blank when a field slip is in play: the person at the keyboard is
  # usually a foray recorder entering someone else's collection, and
  # `ObservationFragment::Who` renders a blank collector on a field-slip
  # observation as "Entered by:" alone rather than falsely naming them.
  # Prefilling would make a missed edit silently misattribute the
  # collection. See #3283. Without a field slip, keep defaulting to the
  # entering user.
  def default_collector
    return nil if params[:field_code].present?

    @user.unique_text_name
  end

  # A slip arrival defaults Locality the way the field slip form does,
  # not the way a plain new-observation form does. The chain (#4907) is
  # the user's most recent slip in this project, then the project's own
  # location, then their last located observation — deliberately ranking
  # the project above the last observation, because someone who has
  # travelled to a foray hasn't entered anything at the site yet, while
  # the project's location contains it. `defaults_from_last_observation_
  # created` alone gets the first slip of every foray wrong.
  def apply_field_slip_location(code)
    location = field_slip_default_location(code)
    return unless location

    @observation.location = location
    @observation.where = location.name
    @location = location
  end

  # Reuses `FieldSlip#calc_location` rather than restating the precedence,
  # so a future change to #4907's ordering moves both forms at once.
  def field_slip_default_location(code)
    field_slip_for_code(code)&.location
  end

  def init_naming_and_vote
    @naming      = Naming.new
    @vote        = Vote.new
    @given_name = params.permit(:name)[:name] || ""
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

    # `specimen` is sticky like the rest: a field slip was originally
    # taken to mean a specimen (#4916), but that is only true of some
    # users. Someone recording a foray without collecting had to uncheck
    # it every time, while someone out collecting for the day had to
    # check it every time. What the same user did last is a better
    # predictor than the presence of a code. See #4932.
    %w[is_collection_location gps_hidden specimen].each do |attr|
      @observation.send(:"#{attr}=", last_observation.send(attr))
    end
    apply_default_locality(last_observation)
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

  # A located (or clean free-text) locality is worth carrying forward;
  # one that would itself trip the dubious-name confirmation is not --
  # as a default it re-prompts on every subsequent create until
  # dislodged (reported: one slip's unrecognized "Sunshine Foray/ ..."
  # haunting every following observation). Fall back to the most
  # recent located observation, or no default at all.
  def apply_default_locality(last_observation)
    source = locality_default_source(last_observation)
    return unless source

    @observation.where = source.where
    @observation.location_id = source.location_id
  end

  def locality_default_source(last_observation)
    return last_observation if usable_default_locality?(last_observation)

    @user.observations.where.not(location_id: nil).
      order(created_at: :desc, id: :desc).first
  end

  def usable_default_locality?(obs)
    return true if obs.location_id
    return false if obs.where.blank?

    # check_db: false, deliberately -- the DB-backed check treats ANY
    # previously used `where` as known (Observation.pluck(:where) is
    # in location_name_cache), which would bless the very free text
    # this guard exists to stop propagating. The syntactic check is
    # deterministic.
    !Location.dubious_name?(Location.user_format(@user, obs.where),
                            false, false)
  end

  # Adding a field-slip project: always check it; for other already-
  # checked projects, keep them checked UNLESS they have their own
  # field_slip_prefix (in which case adding a new field-slip project
  # supersedes them — original ERB had this exclusive behavior).
  #
  # An explicit `?project=` wins over the project derived from the code
  # prefix: `AddDispatchController` sends it precisely so the page the
  # user pressed "Add" on can override the slip's own project.
  def add_field_slip_project(code)
    project = Project.safe_find(params[:project]) ||
              FieldSlip.find_by(code: code)&.project
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
    place_name = params.permit(:place_name)[:place_name]
    if place_name
      # Cannot use @place_name since that's being used for approved_where
      @default_place_name = place_name
      loc = Location.place_name_to_location(@default_place_name, @user)
      @location = loc if loc
    else
      @default_place_name = @observation.place_name(@user)
    end
  end
end
