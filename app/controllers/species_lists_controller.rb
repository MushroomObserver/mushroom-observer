# frozen_string_literal: true

#
#  = Species List Controller
#
#  == Actions
#
#  index_species_list::      List of lists in current query.
#  list_species_lists::      List of lists by date.
#  species_lists_by_title::  List of lists by title.
#  species_lists_by_user::   List of lists created by user.
#  species_list_search::     List of lists matching search.
#
#  show_species_list::       Display notes/etc. and list of species.
#  prev_species_list::       Display previous species list in index.
#  next_species_list::       Display next species list in index.
#
#  download::                Download observation data.
#  make_report::             Save observation data as report.
#  print_labels::            Print observation data as labels.
#
#  name_lister::             Efficient javascripty way to build a list of names.
#  create_species_list::     Create new list.
#  edit_species_list::       Edit existing list.
#  upload_species_list::     Same as edit_species_list but gets list from file.
#  destroy_species_list::    Destroy list.
#  clear_species_list::      Remove all observations from list.
#  add_remove_observations:: Add/remove query results to/from a list.
#  manage_species_lists::    Add/remove one observation from a user's lists.
#  add_observation_to_species_list::      (post method)
#  remove_observation_from_species_list:: (post method)
#
#  *NOTE*: There is some ambiguity between observations and names that makes
#  this slightly confusing.  The end result of a species list is actually a
#  list of Observation's, not Name's.  However, creation and editing is
#  generally accomplished via Name's alone (although see manage_species_lists
#  for the one exception).  In the end all these Name's cause rudimentary
#  Observation's to spring into existence.
#
class SpeciesListsController < ApplicationController
  before_action :login_required

  before_action :disable_link_prefetching, except: [
    :create_species_list,
    :edit_species_list,
    :add_remove_observations,
    :manage_species_lists,
    :show_species_list
  ]

  before_action :require_successful_user, only: [
    :create_species_list, :name_lister
  ]

  around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [
    # Bullet wants us to eager load synonyms for @deprecated_names in
    # edit_species_list, and I thought it would be possible, but I can't
    # get it to work.  Seems to minor to waste any more time on.
    :edit_species_list
  ]

  ##############################################################################
  #
  #  :section: Index
  #
  ##############################################################################

  def index # rubocop:disable Metrics/AbcSize
    if params[:advanced_search].present?
      advanced_search
    elsif params[:pattern].present?
      species_list_search
    elsif params[:by_user].present?
      species_lists_by_user
    elsif params[:for_project].present?
      species_lists_for_project
    elsif params[:by] == "title"
      species_lists_by_title
    elsif params[:by].present?
      index_species_list
    else
      list_species_lists
    end
  end

  # Display list of selected species_lists, based on current Query.
  # (Linked from show_species_list, next to "prev" and "next".)
  def index_species_list
    query = find_or_create_query(:SpeciesList, by: params[:by])
    show_selected_species_lists(query, id: params[:id].to_s,
                                       always_index: true)
  end

  # Display list of all species_lists, sorted by date.
  def list_species_lists
    query = create_query(:SpeciesList, :all, by: :date)
    show_selected_species_lists(query, id: params[:id].to_s, by: params[:by])
  end

  # Display list of user's species_lists, sorted by date.
  def species_lists_by_user
    user = params[:id] ? find_or_goto_index(User, params[:by_user].to_s) : @user
    return unless user

    query = create_query(:SpeciesList, :by_user, user: user)
    show_selected_species_lists(query)
  end

  # Display list of SpeciesList's attached to a given project.
  def species_lists_for_project
    project = find_or_goto_index(Project, params[:for_project].to_s)
    return unless project

    query = create_query(:SpeciesList, :for_project, project: project)
    show_selected_species_lists(query, always_index: 1)
  end

  # Display list of all species_lists, sorted by title.
  def species_lists_by_title
    query = create_query(:SpeciesList, :all, by: :title)
    show_selected_species_lists(query)
  end

  # Display list of SpeciesList's whose title, notes, etc. matches a string
  # pattern.
  def species_list_search
    pattern = params[:pattern].to_s
    spl = SpeciesList.safe_find(pattern) if /^\d+$/.match?(pattern)
    if spl
      redirect_to(action: "show_species_list", id: spl.id)
    else
      query = create_query(:SpeciesList, :pattern_search, pattern: pattern)
      show_selected_species_lists(query)
    end
  end

  # Show selected list of species_lists.
  def show_selected_species_lists(query, args = {})
    @links ||= []
    args = {
      action: :index,
      num_per_page: 20,
      include: [:location, :user],
      letters: "species_lists.title"
    }.merge(args)

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["title",       :sort_by_title.t],
      ["date",        :sort_by_date.t],
      ["user",        :sort_by_user.t],
      ["created_at",  :sort_by_created_at.t],
      [(query.flavor == :by_rss_log ? "rss_log" : "updated_at"),
       :sort_by_updated_at.t]
    ]

    # Paginate by letter if sorting by user.
    args[:letters] =
      if query.params[:by] == "user" ||
         query.params[:by] == "reverse_user"
        "users.login"
      else
        # Can always paginate by title letter.
        args[:letters] = "species_lists.title"
      end

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show
  #
  ##############################################################################

  # def show_species_list
  def show
    store_location
    clear_query_in_session
    pass_query_params
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    case params[:flow]
    when "next"
      redirect_to_next_object(:next, SpeciesList, params[:id]) and return
    when "prev"
      redirect_to_next_object(:prev, SpeciesList, params[:id]) and return
    end

    @canonical_url =
      "#{MO.http_domain}/species_lists/#{@species_list.id}"
    @query = create_query(:Observation, :in_species_list,
                          by: :name, species_list: @species_list)
    store_query_in_session(@query) if params[:set_source].present?
    @query.need_letters = "names.sort_name"
    @pages = paginate_letters(:letter, :page, 100)
    @objects = @query.paginate(@pages, include:
                  [:user, :name, :location, { thumb_image: :image_votes }])
  end

  ##############################################################################
  #
  #  :section: Create and Modify
  #
  ##############################################################################

  # Specialized javascripty form for creating a list of names, at Darvin's
  # request. Links into create_species_list.
  def name_lister
    # Names are passed in as string, one name per line.
    results = params[:results] || ""
    @name_strings = results.chomp.split("\n").map { |n| n.to_s.chomp }
    return if request.method != "POST"

    # (make this an instance var to give unit test access)
    @names = @name_strings.map do |str|
      str.sub!(/\*$/, "")
      name, author = str.split("|")
      name.tr!("ë", "e")
      if author
        Name.find_by(text_name: name, author: author)
      else
        Name.find_by(text_name: name)
      end
    end
    @names.compact!
    case params[:commit]
    when :name_lister_submit_spl.l
      if @user
        @species_list = SpeciesList.new
        clear_query_in_session
        init_name_vars_for_create
        init_member_vars_for_create
        init_project_vars_for_create
        @checklist ||= []
        @list_members = params[:results].tr("|", " ").delete("*")
        render(action: "create_species_list")
      end
    when :name_lister_submit_txt.l
      render_name_list_as_txt(@names)
    when :name_lister_submit_rtf.l
      render_name_list_as_rtf(@names)
    when :name_lister_submit_csv.l
      render_name_list_as_csv(@names)
    else
      flash_error(:name_lister_bad_submit.t(button: params[:commit]))
    end
  end

  def create_species_list
    @species_list = SpeciesList.new
    if request.method == "POST"
      process_species_list(:create)
    else
      init_name_vars_for_create
      init_member_vars_for_create
      init_project_vars_for_create
      init_name_vars_for_clone(params[:clone]) if params[:clone].present?
      @checklist ||= calc_checklist
    end
  end

  def edit_species_list
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    if !check_permission!(@species_list)
      redirect_to(action: "show_species_list", id: @species_list)
    elsif request.method != "POST"
      init_name_vars_for_edit(@species_list)
      init_member_vars_for_edit(@species_list)
      init_project_vars_for_edit(@species_list)
      @checklist ||= calc_checklist
    else
      process_species_list(:update)
    end
  end

  # Form to let user create/edit species_list from file.
  def upload
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    if !check_permission!(@species_list)
      redirect_to(action: "show_species_list", id: @species_list)
    elsif request.method != "POST"
      query = create_query(:Observation, :in_species_list,
                           by: :name, species_list: @species_list)
      @observation_list = query.results
    else
      sorter = NameSorter.new
      @species_list.file = params[:species_list][:file]
      @species_list.process_file_data(sorter)
      init_name_vars_from_sorter(@species_list, sorter)
      init_member_vars_for_edit(@species_list)
      init_project_vars_for_edit(@species_list)
      @checklist ||= calc_checklist
      render(action: "edit_species_list")
    end
  end

  def destroy_species_list
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    if check_permission!(@species_list)
      @species_list.destroy
      id = params[:id].to_s
      flash_notice(:runtime_species_list_destroy_success.t(id: id))
      redirect_to(action: "list_species_lists")
    else
      redirect_to(action: "show_species_list", id: @species_list)
    end
  end

  def clear_species_list
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    if check_permission!(@species_list)
      @species_list.clear
      flash_notice(:runtime_species_list_clear_success.t)
    end
    redirect_to(action: "show_species_list", id: @species_list)
  end

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
        flash_error("Unrecognized names given: #{x}")
      end
      failed = true
    end

    # Are there any ambiguous names?
    unless sorter.only_single_names
      if Rails.env.test?
        x = sorter.multiple_line_strs.map(&:to_s).inspect
        flash_error("Ambiguous names given: #{x}")
      end
      failed = true
    end

    # Are there any deprecated names which haven't been approved?
    if sorter.has_unapproved_deprecated_names
      if Rails.env.test?
        x = sorter.deprecated_names.map(&:display_name).inspect
        flash_error("Found deprecated names: #{x}")
      end
      failed = true
    end

    # Okay, at this point we've apparently validated the new list of names.
    # Save the OTHER changes to the species list, then let this other method
    # (construct_observations) create the observations.  This always succeeds,
    # so we can redirect to show_species_list (or chain to create_location).
    if !failed && @dubious_where_reasons == []
      if @species_list.save
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
          redirect_to(controller: "location", action: "create_location",
                      where: @place_name, set_species_list: @species_list.id)
        else
          redirect_to(action: "show_species_list", id: @species_list)
        end
        redirected = true
      else
        flash_object_errors(@species_list)
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
    return unless query ||= query_from_session

    case query.model.name
    when "Name"
      checklist_from_name_query(query)
    when "Observation"
      checklist_from_observation_query(query)
    when "Image"
      checklist_from_image_query(query)
    when "Location"
      checklist_from_location_query(query)
    when "RssLog"
      checklist_from_rss_log_query(query)
    end
  end

  def checklist_from_name_query(query)
    query.select_rows(
      select: "DISTINCT names.display_name, names.id",
      limit: 1000
    )
  end

  def checklist_from_observation_query(query)
    query.select_rows(
      select: "DISTINCT names.display_name, names.id",
      join: :names,
      limit: 1000
    )
  end

  def checklist_from_image_query(query)
    query.select_rows(
      select: "DISTINCT names.display_name, names.id",
      join: { observation_images: { observations: :names } },
      limit: 1000
    )
  end

  def checklist_from_location_query(query)
    query.select_rows(
      select: "DISTINCT names.display_name, names.id",
      join: { observations: :names },
      limit: 1000
    )
  end

  def checklist_from_rss_log_query(query)
    query.select_rows(
      select: "DISTINCT names.display_name, names.id",
      join: { observations: :names },
      where: "rss_logs.observation_id > 0",
      limit: 1000
    )
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
    @deprecated_names = spl.names.where(deprecated: true)
    @place_name = spl.place_name
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
    @projects = User.current.projects_member(order: :title,
                                             include: { user_group: :users })
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
    Project.where(id: User.current.projects_member.map(&:id)).
      includes(:species_lists).each do |project|
      before = spl.projects.include?(project)
      after = checks["id_#{project.id}"] == "1"
      next if before == after

      change_project_species_lists(
        project: project, spl: spl, change: (after ? :add : :remove)
      )
      any_changes = true
    end

    flash_notice(:species_list_show_manage_observations_too.t) if any_changes
  end

  ##############################################################################

  private

  def change_project_species_lists(project:, spl:, change: :add)
    if change == :add
      project.add_species_list(spl)
      flash_notice(:attached_to_project.t(object: :species_list,
                                          project: project.title))
    else
      project.remove_species_list(spl)
      flash_notice(:removed_from_project.t(object: :species_list,
                                           project: project.title))
    end
  end

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
