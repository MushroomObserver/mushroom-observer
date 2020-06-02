# frozen_string_literal: true

# see app/controllers/species_lists_controller.rb
class SpeciesListsController

  ##############################################################################
  #
  #  :section: Helpers
  #
  ##############################################################################

  # Validate list of names, and if successful, create observations.
  # Parameters involved in name list validation:
  #   params[:list][:members]               String user typed in big text area
  #                                         on right side (squozen and stripped)
  #   params[:approved_names]               New names from prev post.
  #   params[:approved_deprecated_names]    Deprecated names from prev post.
  #   params[:chosen_multiple_names][name]  Radios for choosing ambiguous names.
  #   params[:chosen_approved_names][name]  Radios for choose accepted names.
  #     (Both the last two radio boxes are hashes with:
  #       key: ambiguous name as typed with nonalphas changed to underscores,
  #       val: id of name user has chosen (via radio boxes in feedback)
  #   params[:checklist_data][...]          Radios: hash from name id to "1".
  #   params[:checklist_names][name_id]     (Used by view to give a name to each
  #                                         id in checklist_data hash.)

  # TODO NIMMO: Can we break this method into some shorter methods?
  def process_species_list(create_or_update)
    redirected = false

    # Update the timestamps/user/when/where/title/notes fields.
    now = Time.zone.now
    @species_list.created_at = now if create_or_update == :create
    @species_list.updated_at = now
    @species_list.user = @user
    if params[:species_list]
      args = params[:species_list]
      @species_list.attributes = args.permit(whitelisted_species_list_args)
    end
    @species_list.title = @species_list.title.to_s.strip_squeeze
    if Location.is_unknown?(@species_list.place_name) ||
       @species_list.place_name.blank?
      @species_list.location = Location.unknown
      @species_list.where = nil
    end

    # Validate place name.
    @place_name = @species_list.place_name
    @dubious_where_reasons = []
    if @place_name != params[:approved_where] && @species_list.location.nil?
      db_name = Location.user_name(@user, @place_name)
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
    end

    # Make sure all the names (that have been approved) exist.
    list = if params[:list]
             params[:list][:members].to_s.tr("_", " ").strip_squeeze
           else
             ""
           end
    construct_approved_names(list, params[:approved_names])

    # Initialize NameSorter and give it all the information.
    sorter = NameSorter.new
    sorter.add_chosen_names(params[:chosen_multiple_names])
    sorter.add_chosen_names(params[:chosen_approved_names])
    sorter.add_approved_deprecated_names(params[:approved_deprecated_names])
    sorter.check_for_deprecated_checklist(params[:checklist_data])
    sorter.check_for_deprecated_names(@species_list.names) if @species_list.id
    sorter.sort_names(list)

    # Now let us count all the ways in which NameSorter can fail...
    failed = false

    # Does list have "Name one = Name two" type lines?
    if sorter.has_new_synonyms
      flash_error(:runtime_species_list_need_to_use_bulk.t)
      sorter.reset_new_names
      failed = true
    end

    # Are there any unrecognized names?
    if sorter.new_name_strs != []
      if Rails.env.test?
        x = sorter.new_name_strs.map(&:to_s).inspect
        flash_error "Unrecognized names given: #{x}"
      end
      failed = true
    end

    # Are there any ambiguous names?
    unless sorter.only_single_names
      if Rails.env.test?
        x = sorter.multiple_line_strs.map(&:to_s).inspect
        flash_error "Ambiguous names given: #{x}"
      end
      failed = true
    end

    # Are there any deprecated names which haven't been approved?
    if sorter.has_unapproved_deprecated_names
      if Rails.env.test?
        x = sorter.deprecated_names.map(&:display_name).inspect
        flash_error "Found deprecated names: #{x}"
      end
      failed = true
    end

    # Okay, at this point we've apparently validated the new list of names.
    # Save the OTHER changes to the species list, then let this other method
    # (construct_observations) create the observations.  This always succeeds,
    # so we can redirect to controller: :species_lists, action: :show
    # or chain to controller: locations, action: :create.
    if !failed && @dubious_where_reasons == []
      if !@species_list.save
        flash_object_errors(@species_list)
      else
        if create_or_update == :create
          @species_list.log(:log_species_list_created)
          id = @species_list.id
          flash_notice(:runtime_species_list_create_success.t(id: id))
        else
          @species_list.log(:log_species_list_updated)
          id = @species_list.id
          flash_notice(:runtime_species_list_edit_success.t(id: id))
        end

        update_projects(@species_list, params[:project])
        construct_observations(@species_list, sorter)

        if @species_list.location.nil?
          # redirect_to(
          #   controller: :locations,
          #   action: :create,
          #   where: @place_name,
          #   set_species_list: @species_list.id
          # )
          redirect_to new_location_path(
            where: @place_name,
            set_species_list: @species_list.id
          )
        elsif unshown_notifications?(@user, :naming)
          # redirect_to controller: :notifications, action: :show
          redirect_to notification_path
        else
          redirect_to species_list_path(@species_list.id)
        end
        redirected = true
      end
    end

    return if redirected

    # Failed to create due to synonyms, unrecognized names, etc.
    init_name_vars_from_sorter(@species_list, sorter)
    init_member_vars_for_reload
    init_project_vars_for_reload(@species_list)
  end

  # Creates observations for names written in and/or selected from checklist.
  # Uses the member instance vars, as well as:
  #   params[:chosen_approved_names]    Names from radio boxes.
  #   params[:checklist_data]           Names from LHS check boxes.
  def construct_observations(spl, sorter)
    # Put together a list of arguments to use when creating new observations.
    member_args = params[:member] || {}
    member_notes = clean_notes(member_args[:notes])
    sp_args = {
      created_at: spl.updated_at,
      updated_at: spl.updated_at,
      user: @user,
      projects: spl.projects,
      location: spl.location,
      where: spl.where,
      vote: member_args[:vote],
      notes: member_notes,
      lat: member_args[:lat].to_s,
      long: member_args[:long].to_s,
      alt: member_args[:alt].to_s,
      is_collection_location: (member_args[:is_collection_location] == "1"),
      specimen: (member_args[:specimen] == "1")
    }

    # This updates certain observation namings already in the list.  It looks
    # for namings that are deprecated, then replaces them with approved
    # synonyms which the user has chosen via radio boxes in
    # params[:chosen_approved_names].
    if (chosen_names = params[:chosen_approved_names])
      spl.observations.each do |observation|
        observation.namings.each do |naming|
          # (compensate for gsub in _form_species_lists)
          next unless (alt_name_id = chosen_names[naming.name_id.to_s])

          alt_name = Name.find(alt_name_id)
          naming.name = alt_name
          naming.save
        end
      end
    end

    # Add all names from text box into species_list.  Creates a new observation
    # for each name.  ("single names" are names that matched a single name
    # uniquely.)
    sorter.single_names.each do |name, timestamp|
      sp_args[:when] = timestamp || spl.when
      spl.construct_observation(name, sp_args)
    end

    # Add checked names from LHS check boxes.  It doesn't check if they are
    # already in there; it creates new observations for each and stuffs it in.
    sp_args[:when] = spl.when
    return unless params[:checklist_data]

    params[:checklist_data].each do |key, value|
      next unless value == "1"

      name = find_chosen_name(key.to_i, params[:chosen_approved_names])
      spl.construct_observation(name, sp_args)
    end
  end

  def clean_notes(notes_in)
    return {} if notes_in.blank?

    notes_out = {}
    notes_in.each do |key, val|
      notes_out[key.to_sym] = val.to_s if val.present?
    end
    notes_out
  end

  def find_chosen_name(id, alternatives)
    if alternatives &&
       (alt_id = alternatives[id.to_s])
      Name.find(alt_id)
    else
      Name.find(id)
    end
  end

  # Called by the actions which use create/edit_species_list form.  It grabs a
  # list of names to list with checkboxes in the left-hand column of the form.
  # By default it looks up a query stored in the session (you can, for example,
  # "save" another species list "for later" for this purpose).  The result is
  # an Array of names where the values are [display_name, name_id].  This
  # is destined for the instance variable @checklist.
  def calc_checklist(query = nil)
    results = []
    if query || (query = query_from_session)
      results = case query.model
                when Name
                  query.select_rows(
                    select: "DISTINCT names.display_name, names.id",
                    limit: 1000
                  )
                when Observation
                  query.select_rows(
                    select: "DISTINCT names.display_name, names.id",
                    join: :names,
                    limit: 1000
                  )
                when Image
                  query.select_rows(
                    select: "DISTINCT names.display_name, names.id",
                    join: { images_observations: { observations: :names } },
                    limit: 1000
                  )
                when Location
                  query.select_rows(
                    select: "DISTINCT names.display_name, names.id",
                    join: { observations: :names },
                    limit: 1000
                  )
                when RssLog
                  query.select_rows(
                    select: "DISTINCT names.display_name, names.id",
                    join: { observations: :names },
                    where: "rss_logs.observation_id > 0",
                    limit: 1000
                  )
                else
                  []
                end
    end
    results
  end

  def init_name_vars_for_create
    @checklist_names = {}
    @new_names = []
    @multiple_names = []
    @deprecated_names = []
    @list_members = nil
    @checklist = nil
    @place_name = nil
  end

  def init_name_vars_for_edit(spl)
    init_name_vars_for_create
    @deprecated_names = spl.names.select(&:deprecated)
    @place_name = spl.place_name
    params[:approved_where] = @place_name
  end

  def init_name_vars_for_clone(clone_id)
    return unless (clone = SpeciesList.safe_find(clone_id))

    query = create_query(:Observation, :in_species_list, species_list: clone)
    @checklist = calc_checklist(query)
    @species_list.when = clone.when
    @species_list.place_name = clone.place_name
    @species_list.location = clone.location
    @species_list.title = clone.title
  end

  def init_name_vars_from_sorter(spl, sorter)
    @checklist_names = params[:checklist_data] || {}
    @new_names = sorter.new_name_strs.uniq.sort
    @multiple_names = sorter.multiple_names.uniq.sort_by(&:search_name)
    @deprecated_names = sorter.deprecated_names.uniq.sort_by(&:search_name)
    @list_members = sorter.all_line_strs.join("\r\n")
    @checklist = nil
    @place_name = spl.place_name
  end

  def init_member_vars_for_create
    @member_vote = Vote.maximum_vote
    @member_notes_parts = @species_list.form_notes_parts(@user)
    @member_notes = @member_notes_parts.each_with_object({}) do |part, h|
      h[part.to_sym] = ""
    end
    @member_lat = nil
    @member_long = nil
    @member_alt = nil
    @member_is_collection_location = true
    @member_specimen = false
  end

  def init_member_vars_for_edit(spl)
    init_member_vars_for_create
    spl_obss = spl.observations
    return unless (obs = spl_obss.last)

    # Not sure how to check vote efficiently...
    @member_vote = begin
                     obs.namings.first.users_vote(@user).value
                   rescue StandardError
                     Vote.maximum_vote
                   end
    init_member_notes_for_edit(spl_obss)
    if all_obs_same_lat_lon_alt?(spl_obss)
      @member_lat  = obs.lat
      @member_long = obs.long
      @member_alt  = obs.alt
    end
    if all_obs_same_attr?(spl_obss, :is_collection_location)
      @member_is_collection_location = obs.is_collection_location
    end
    @member_specimen = obs.specimen if all_obs_same_attr?(spl_obss, :specimen)
  end

  def init_member_notes_for_edit(observations)
    if all_obs_same_attr?(observations, :notes)
      obs = observations.last
      obs.form_notes_parts(@user).each do |part|
        @member_notes[part.to_sym] = obs.notes_part_value(part)
      end
    else
      @species_list.form_notes_parts(@user).each do |part|
        @member_notes[part.to_sym] = ""
      end
    end
  end

  def all_obs_same_lat_lon_alt?(observations)
    all_obs_same_attr?(observations, :lat) &&
      all_obs_same_attr?(observations, :long) &&
      all_obs_same_attr?(observations, :alt)
  end

  # Do all observations have same values for the single given attribute?
  def all_obs_same_attr?(observations, attr)
    exemplar = observations.first.send(attr)
    observations.all? { |o| o.send(attr) == exemplar }
  end

  def init_member_vars_for_reload
    member_params    = params[:member] || {}
    @member_vote     = member_params[:vote].to_s
    # cannot leave @member_notes == nil because view expects a hash
    @member_notes    = member_params[:notes] || Observation.no_notes
    @member_lat      = member_params[:lat].to_s
    @member_long     = member_params[:long].to_s
    @member_alt      = member_params[:alt].to_s
    @member_is_collection_location =
      member_params[:is_collection_location].to_s == "1"
    @member_specimen = member_params[:specimen].to_s == "1"
  end

  def init_project_vars
    @projects = User.current.projects_member(order: :title)
    @project_checks = {}
  end

  def init_project_vars_for_create
    init_project_vars
    last_obs = Observation.where(user_id: User.current_id).
               order(:created_at).last
    return unless last_obs && last_obs.created_at > 1.hour.ago

    last_obs.projects.each { |proj| @project_checks[proj.id] = true }
  end

  def init_project_vars_for_edit(spl)
    init_project_vars
    spl.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
      @project_checks[proj.id] = true
    end
  end

  def init_project_vars_for_reload(spl)
    init_project_vars
    spl.projects.each do |proj|
      @projects << proj unless @projects.include?(proj)
    end
    @projects.each do |proj|
      @project_checks[proj.id] = params[:project] &&
                                 params[:project]["id_#{proj.id}"] == "1"
    end
  end

  def update_projects(spl, checks)
    return unless checks

    any_changes = false
    User.current.projects_member.each do |project|
      before = spl.projects.include?(project)
      after = checks["id_#{project.id}"] == "1"
      next if before == after

      if after
        project.add_species_list(spl)
        flash_notice(:attached_to_project.t(object: :species_list,
                                            project: project.title))
      else
        project.remove_species_list(spl)
        flash_notice(:removed_from_project.t(object: :species_list,
                                             project: project.title))
      end
      any_changes = true
    end
    flash_notice(:species_list_show_manage_observations_too.t) if any_changes
  end

  ##############################################################################

  private

  def whitelisted_species_list_args
    ["when(1i)", "when(2i)", "when(3i)", :place_name, :title, :notes]
  end

  def bulk_editor_new_val(attr, val)
    case attr
    when :is_collection_location, :specimen
      val == "1"
    else
      val
    end
  end

end
