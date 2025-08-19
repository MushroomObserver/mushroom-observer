# frozen_string_literal: true

#  :index
#   params:
#   advanced_search:
#   pattern:
#   country:
#   project:
#   by_user:
#   by_editor:
#  :show,
#  :new,
#  :create,
#  :edit,
#  :update,
#  :destroy

# Locations controller.
# rubocop:disable Metrics/ClassLength
class LocationsController < ApplicationController
  before_action :store_location, except: [:index, :destroy]
  before_action :pass_query_params, except: [:index]
  before_action :login_required

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  private

  def default_sort_order
    ::Query::Locations.default_order # :name
  end

  def unfiltered_index_opts
    super.merge(display_opts: { link_all_sorts: true })
  end

  # ApplicationController uses this to dispatch #index to a private method
  def index_active_params
    [:advanced_search, :pattern, :country, :project, :by_user, :by_editor,
     :by, :q, :id].freeze
  end

  # Displays matrix of advanced search results.
  def advanced_search
    return if handle_advanced_search_invalid_q_param?

    query = find_query(:Location)
    # Have to check this here because we're not running the query yet.
    raise(:runtime_no_conditions.l) unless query&.params&.any?

    [query, { link_all_sorts: true }]
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(search_advanced_path)
    [nil, {}]
  end

  # Displays a list of locations matching a given string.
  def pattern
    pattern = params[:pattern].to_s
    loc = Location.safe_find(pattern) if /^\d+$/.match?(pattern)
    if loc
      redirect_to(location_path(loc.id))
      [nil, {}]
    else
      query = create_query(
        :Location, pattern: Location.user_format(@user, pattern)
      )
      [query, { link_all_sorts: true }]
    end
  end

  # Displays a list of all locations whose country matches the param.
  def country
    query = create_query(:Location, regexp: "#{params[:country]}$")
    [query, { link_all_sorts: true }]
  end

  # Displays a list of locations of obs whose project matches the param.
  def project
    obs_query = create_query(:Observation,
                             projects: Project.find(params[:project]))
    query = create_query(:Location, observation_query: obs_query.params)
    [query, { link_all_sorts: true }]
  end

  # Display list of locations that a given user created.
  def by_user
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:by_user].to_s,
      index_path: locations_path
    )
    return unless user

    query = create_query(:Location, by_users: user)
    [query, { link_all_sorts: true }]
  end

  # Display list of locations that a given user is editor on.
  def by_editor
    editor = find_obj_or_goto_index(
      model: User, obj_id: params[:by_editor].to_s,
      index_path: locations_path
    )
    return unless editor

    query = create_query(:Location, by_editor: editor)
    [query, {}]
  end

  # Hook runs before template displayed. Must return query.
  def filtered_index_final_hook(query, display_opts)
    # Matching undefined locations is meaningless in a box.
    # (Undefined locations don't have a box!)
    return query if query.params[:in_box].present?

    # Get matching *undefined* locations.
    set_matching_undefined_location_ivars(query, display_opts)
    query
  end

  # Paginate the defined locations using the usual helper.
  def index_display_opts(opts, _query)
    { always_index: @undef_pages&.num_total&.positive? }.merge(opts)
  end

  def set_matching_undefined_location_ivars(query, display_opts)
    unless (query2 = create_query_for_obs_undefined_where_strings(query))
      @undef_pages = nil
      @undef_data = nil
      return false
    end

    @undef_location_format = @user.location_format
    if display_opts[:link_all_sorts]
      # (This tells it to say "by name" and "by frequency" by the subtitles.
      # If user has explicitly selected the order, then this is disabled.)
      @default_orders = true
    end
    @undef_pages = letter_pagination_data(:letter2, :page2,
                                          display_opts[:num_per_page] || 50)
    @undef_data = query2.paginate(@undef_pages)
    @undef_pages.used_letters = @undef_data.map { |obs| obs[:where][0, 1] }.uniq
    if (letter = params[:letter2].to_s.downcase) != ""
      @undef_data = @undef_data.select do |obs|
        obs[:where][0, 1].downcase == letter
      end
    end
    @undef_pages.num_total = @undef_data.length
    @undef_data = @undef_data[@undef_pages.from..@undef_pages.to]
  end

  ##############################################################################

  public # for test!

  # Try to turn this into a query on observations.where instead.
  # Yes, still a kludge, but a little better than tweaking SQL by hand...
  def create_query_for_obs_undefined_where_strings(query)
    args   = query.params.dup.except(:observation_query)
    # Location params not handled by Observation. (does handle :by_user)
    # If these are passed, we're not looking for undefined locations.
    return nil if [:by_editor, :regexp].any? { |key| args[key] }

    # # Select only observations with undefined location.
    # args[:where] = [args[:where]].flatten.compact

    # "By name" means something different to observation.
    nosorts = ["name", "box_area", "reverse_name", "reverse_box_area", ""]
    args[:order_by] = "where" if nosorts.include?(args[:order_by])

    args[:search_where] ||= ""
    if args[:pattern]
      args[:search_where] += args[:pattern]
      args.delete(:pattern)
    end

    # Create query if okay.  (Still need to tweak select and group clauses.)
    result = create_query(:Observation, args.merge(location_undefined: true))

    # Also make sure the sql doesn't reference locations anywhere.  This would
    # presumably be the result of customization of one of the above.
    result = nil if /\Wlocations\./.match?(result.sql)

    result
  end

  ##############################################################################

  # Show a Location and one of its LocationDescription's, including a map.
  def show
    clear_query_in_session
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, Location, params[:id].to_s)
    when "prev"
      redirect_to_next_object(:prev, Location, params[:id].to_s)
    end

    # Load Location and LocationDescription along with a bunch of associated
    # objects.
    desc_id = params[:desc]
    return unless find_location!

    @canonical_url = "#{MO.http_domain}/locations/#{@location.id}"

    # Load default description if user didn't request one explicitly.
    desc_id = @location.description_id if desc_id.blank?
    init_description_ivar(desc_id)
    update_view_stats(@location)
    update_view_stats(@description) if @description

    @versions = @location.versions
    # Save two lookups in comments_for_object
    @comments = @location.comments&.sort_by(&:created_at)&.reverse
    @desc_comments = @description&.comments&.sort_by(&:created_at)&.reverse
    init_projects_ivar
  end

  def new
    init_caller_ivars_for_new

    # Render a blank form.
    user_format = Location.user_format(@user, @display_name)
    if @display_name
      @dubious_where_reasons = Location.dubious_name?(user_format, true)
    end
    @location = Location.new

    respond_to do |format|
      format.turbo_stream { render_modal_location_form }
      format.html
    end
  end

  def create
    init_caller_ivars_for_new
    # Set to true below if created successfully, or if a matching location
    # already exists.  In either case, we're done with this form.
    done = false

    # Look to see if the display name is already in use.
    # If it is then just use that location and ignore the other values.
    # Probably should be smarter with warnings and merges and such...
    db_name = Location.user_format(@user, @display_name)
    @location = Location.find_by_name_or_reverse_name(db_name)

    # Location already exists.
    if @location
      flash_warning(:runtime_location_already_exists.t(name: @display_name))
      done = true

    # Need to create location.
    else
      done = create_location_ivar_and_save(done, db_name)
    end

    # If done, update any observations at @display_name,
    # and set user's primary location if called from profile.
    return render_new unless done

    if @original_name.present?
      db_name = Location.user_format(@user, @original_name)
      Observation.define_a_location(@location, db_name)
      SpeciesList.define_a_location(@location, db_name)
    end
    return_to_caller
  end

  def edit
    return unless find_location!

    params[:location] ||= {}
    @display_name = @location.display_name

    respond_to do |format|
      format.turbo_stream { render_modal_location_form }
      format.html
    end
  end

  def update
    return unless find_location!

    params[:location] ||= {}
    @display_name = params[:location][:display_name].strip_squeeze
    db_name = Location.user_format(@user, @display_name)
    merge = Location.find_by_name_or_reverse_name(db_name)
    if merge && merge != @location
      update_location_merge(merge)
    else
      email_admin_location_change if nontrivial_location_change?
      update_location_change(db_name)
    end
  end

  def destroy
    return unless in_admin_mode?
    return unless find_location!

    if @location.destroy
      flash_notice(:runtime_destroyed_id.t(type: :location, value: params[:id]))
    end
    redirect_to(locations_path)
  end

  ##############################################################################

  private

  def find_location!
    @location = Location.show_includes.safe_find(params[:id]) ||
                flash_error_and_goto_index(Location, params[:id])
  end

  def render_new
    render("new", location: new_location_path)
  end

  def render_edit
    render("edit", location: edit_location_path(@location))
  end

  def init_description_ivar(desc_id)
    if desc_id.blank?
      @description = nil
    elsif (@description = LocationDescription.safe_find(desc_id))
      @description = nil unless in_admin_mode? || @description.is_reader?(@user)
    else
      flash_error(:runtime_object_not_found.t(type: :description,
                                              id: desc_id))
    end
  end

  def init_projects_ivar
    # Get a list of projects the user can create drafts for.
    @projects = @user&.projects_member&.select do |project|
      @location.descriptions.none? { |d| d.belongs_to_project?(project) }
    end
  end

  def init_caller_ivars_for_new
    # Original name passed in when arrive here with express purpose of
    # defining a given location. (e.g., clicking on "define this location",
    # or after create_observation with unknown location)
    # Note: names are in user's preferred order unless explicitly otherwise.)
    @original_name = params[:where]

    # Previous value of place name: ignore warnings if unchanged
    # (i.e., resubmit same name).
    @approved_name = params[:approved_where]

    # This is the latest value of place name.
    @display_name = begin
                      params[:location][:display_name].strip_squeeze
                    rescue StandardError
                      @original_name
                    end

    # Where to return after successfully creating location.
    @set_observation  = params[:set_observation]
    @set_species_list = params[:set_species_list]
    @set_user         = params[:set_user]
    @set_herbarium    = params[:set_herbarium]
  end

  def create_location_ivar_and_save(done, db_name)
    @location = Location.new(permitted_location_params)
    @location.display_name = @display_name # (strip_squozen)

    # Validate name.
    @dubious_where_reasons = []
    if @display_name != @approved_name
      @dubious_where_reasons = Location.dubious_name?(db_name, true)
    end

    if @dubious_where_reasons.empty?
      if @location.save
        flash_notice(:runtime_location_success.t(id: @location.id))
        done = true
      else
        # Failed to create location
        flash_object_errors(@location)
      end
    end
    done
  end

  def return_to_caller
    if @set_observation
      redirect_to(observation_path(@set_observation))
    elsif @set_species_list
      redirect_to(species_list_path(@set_species_list))
    elsif @set_herbarium
      if (herbarium = Herbarium.safe_find(@set_herbarium))
        herbarium.location = @location
        herbarium.save
        redirect_to(herbarium_path(@set_herbarium))
      end
    elsif @set_user
      if (user = User.safe_find(@set_user))
        user.location = @location
        user.save
        redirect_to(user_path(@set_user.id))
      end
    else
      redirect_to(location_path(@location.id))
    end
  end

  # Merge this location with another.
  def update_location_merge(merge)
    if !@location.mergable? && merge.mergable?
      @location, merge = merge, @location
    end
    if in_admin_mode? || @location.mergable?
      old_name = @location.display_name
      new_name = merge.display_name
      merge.merge(@user, @location)
      merge.save if merge.changed?
      @location = merge
      flash_notice(:runtime_location_merge_success.t(this: old_name,
                                                     that: new_name))
      redirect_to(@location.show_link_args)
    else
      redirect_with_query(new_admin_emails_merge_requests_path(
                            type: :Location, old_id: @location.id,
                            new_id: merge.id
                          ))
    end
  end

  # Just change this location in place.
  def update_location_change(db_name)
    @dubious_where_reasons = []
    @location.notes = params[:location][:notes].to_s.strip
    @location.locked = params[:location][:locked] == "1" if in_admin_mode?
    determine_and_check_location(db_name) if !@location.locked || in_admin_mode?
    return render_edit unless @dubious_where_reasons.empty?

    save_flash_and_redirect_or_render!
  end

  def determine_and_check_location(db_name)
    @location.north = params[:location][:north] if params[:location][:north]
    @location.south = params[:location][:south] if params[:location][:south]
    @location.east  = params[:location][:east]  if params[:location][:east]
    @location.west  = params[:location][:west]  if params[:location][:west]
    @location.high  = params[:location][:high]  if params[:location][:high]
    @location.low   = params[:location][:low]   if params[:location][:low]
    @location.display_name = @display_name
    return unless @display_name != params[:approved_where]

    @dubious_where_reasons = Location.dubious_name?(db_name, true)
  end

  def save_flash_and_redirect_or_render!
    if !@location.changed?
      flash_warning(:runtime_edit_location_no_change.t)
      redirect_to(location_path(@location.id))
    elsif !@location.save
      flash_object_errors(@location)
      render_edit
    else
      flash_notice(:runtime_edit_location_success.t(id: @location.id))
      redirect_to(location_path(@location.id))
    end
  end

  def nontrivial_location_change?
    old_name = @location.display_name
    new_name = @display_name
    new_name.percent_match(old_name) < 0.9
  end

  def email_admin_location_change
    content = email_location_change_content
    QueuedEmail::Webmaster.create_email(
      @user,
      subject: "Nontrivial Location Change",
      content: content
    )
    LocationsControllerTest.report_email(content) if Rails.env.test?
  end

  def email_location_change_content
    :email_location_change.l(
      user: @user.login,
      old: @location.display_name,
      new: @display_name,
      observations: @location.observations.length,
      show_url: "#{MO.http_domain}/locations/#{@location.id}",
      edit_url: "#{MO.http_domain}/locations/#{@location.id}/edit"
    )
  end

  def render_modal_location_form
    render(partial: "shared/modal_form",
           locals: { title: modal_title, identifier: modal_identifier,
                     user: @user, form: "locations/form" }) and return
  end

  def modal_identifier
    case action_name
    when "new", "create"
      "location"
    when "edit", "update"
      "location_#{@location.id}"
    end
  end

  def modal_title
    case action_name
    when "new", "create"
      new_page_title(:create_object, :LOCATION)
    when "edit", "update"
      edit_page_title(@location.display_name, @location)
    end
  end

  ##############################################################################

  def permitted_location_params
    params.require(:location).
      permit(:display_name,
             :north, :west, :east, :south, :high, :low,
             :notes, :hidden)
  end
end
# rubocop:enable Metrics/ClassLength
