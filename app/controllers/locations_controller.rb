# frozen_string_literal: true

#  :index
#   params:
#   advanced_search:
#   pattern:
#   country:
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
  # disable cop because index is defined in ApplicationController
  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :store_location, except: [:index, :destroy]
  before_action :pass_query_params, except: [:index]
  # rubocop:enable Rails/LexicallyScopedActionFilter
  before_action :login_required

  ##############################################################################
  #
  # index::

  # ApplicationController uses this to dispatch #index to a private method
  @index_subaction_param_keys = [
    :advanced_search,
    :pattern,
    :country,
    :by_user,
    :by_editor,
    :by,
    :q,
    :id
  ].freeze

  @index_subaction_dispatch_table = {
    by: :index_query_results,
    q: :index_query_results,
    id: :index_query_results
  }.freeze

  #############################################

  private # private methods used by #index

  def default_index_subaction
    list_locations
  end

  # Displays a list of all locations.
  def list_locations
    query = create_query(:Location, :all, by: default_sort_order)
    show_selected_locations(query, link_all_sorts: true)
  end

  def default_sort_order
    ::Query::LocationBase.default_order
  end

  # Displays a list of selected locations, based on current Query.
  def index_query_results
    query = find_or_create_query(:Location, by: params[:by])
    show_selected_locations(query, id: params[:id].to_s, always_index: true)
  end

  # Displays matrix of advanced search results.
  def advanced_search
    return if handle_advanced_search_invalid_q_param?

    query = find_query(:Location)
    show_selected_locations(query, link_all_sorts: true)
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    redirect_to(search_advanced_path)
  end

  # Displays a list of locations matching a given string.
  def pattern
    pattern = params[:pattern].to_s
    loc = Location.safe_find(pattern) if /^\d+$/.match?(pattern)
    if loc
      redirect_to(location_path(loc.id))
    else
      query = create_query(
        :Location, :pattern_search,
        pattern: Location.user_format(@user, pattern)
      )
      show_selected_locations(query, link_all_sorts: true)
    end
  end

  # Displays a list of all locations whose country matches the id param.
  def country
    query = create_query(
      :Location, :regexp_search, regexp: "#{params[:country]}$"
    )
    show_selected_locations(query, link_all_sorts: true)
  end

  # Display list of locations that a given user created.
  def by_user
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:by_user].to_s,
      index_path: locations_path
    )
    return unless user

    query = create_query(:Location, :by_user, user: user)
    show_selected_locations(query, link_all_sorts: true)
  end

  # Display list of locations that a given user is editor on.
  def by_editor
    user = find_obj_or_goto_index(
      model: User, obj_id: params[:by_editor].to_s,
      index_path: locations_path
    )
    return unless user

    query = create_query(:Location, :by_editor, user: user)
    show_selected_locations(query)
  end

  # Show selected search results as a list with 'list_locations' template.
  def show_selected_locations(query, args = {})
    # Restrict to subset within a geographical region (used by map
    # if it needed to stuff multiple locations into a single marker).
    query = restrict_query_to_box(query)

    # Get matching *undefined* locations.
    get_matching_undefined_locations(query, args)

    # Paginate the defined locations using the usual helper.
    args[:always_index] = @undef_pages&.num_total&.positive?
    args[:action] = args[:action] || :index
    show_index_of_objects(query, args)
  end

  def get_matching_undefined_locations(query, args)
    @undef_location_format = User.current_location_format
    if (query2 = coerce_query_for_undefined_locations(query))
      select_args = {
        group: "observations.where",
        select: "observations.where AS w, COUNT(observations.id) AS c"
      }
      if args[:link_all_sorts]
        select_args[:order] = "c DESC"
        # (This tells it to say "by name" and "by frequency" by the subtitles.
        # If user has explicitly selected the order, then this is disabled.)
        @default_orders = true
      end
      @undef_pages = paginate_letters(:letter2,
                                      :page2,
                                      args[:num_per_page] || 50)
      @undef_data = query2.select_rows(select_args)
      @undef_pages.used_letters = @undef_data.map { |row| row[0][0, 1] }.uniq
      if (letter = params[:letter2].to_s.downcase) != ""
        @undef_data = @undef_data.select do |row|
          row[0][0, 1].downcase == letter
        end
      end
      @undef_pages.num_total = @undef_data.length
      @undef_data = @undef_data[@undef_pages.from..@undef_pages.to]
    else
      @undef_pages = nil
      @undef_data = nil
    end
  end

  #############################################

  public # for test!

  # Try to turn this into a query on observations.where instead.
  # Yes, still a kludge, but a little better than tweaking SQL by hand...
  def coerce_query_for_undefined_locations(query)
    model  = :Observation
    flavor = query.flavor
    args   = query.params.dup
    result = nil

    # Select only observations with undefined location.
    if !args[:where]
      args[:where] = []
    elsif !args[:where].is_a?(Array)
      args[:where] = [args[:where]]
    end
    args[:where] << "observations.location_id IS NULL"

    # "By name" means something different to observation.
    if args[:by].blank? ||
       (args[:by] == "name")
      args[:by] = "where"
    end

    case query.flavor

    # These are okay as-is.
    when :all, :by_user
      true

    # Simple coercions.
    when :with_observations
      flavor = :all
    when :with_observations_by_user
      flavor = :by_user
    when :with_observations_for_project
      flavor = :for_project
    when :with_observations_in_set
      flavor = :in_set
    when :with_observations_in_species_list
      flavor = :in_species_list

    # Temporarily kludge in pattern search the old way.
    when :pattern_search
      flavor = :all
      search = query.google_parse(args[:pattern])
      args[:where] += query.google_conditions(search, "observations.where")
      args.delete(:pattern)

    # when :regexp_search  ### NOT SURE WHAT DO FOR THIS

    # None of the rest make sense.
    else
      flavor = nil
    end

    # These are only used to create title, which isn't used,
    # they just get in the way.
    args.delete(:old_title)
    args.delete(:old_by)

    # Create query if okay.  (Still need to tweak select and group clauses.)
    if flavor
      result = create_query(model, flavor, args)

      # Also make sure it doesn't reference locations anywhere.  This would
      # presumably be the result of customization of one of the above flavors.
      result = nil if /\Wlocations\./.match?(result.query)
    end

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
    @comments = @location.comments&.sort_by { |cmt| cmt[:created_at] }&.reverse
    @desc_comments = @description.comments&.
                     sort_by { |cmt| cmt[:created_at] }&.reverse
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
      done = create_location_ivar(done, db_name)
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
    update if request.method == "POST"
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

  def create_location_ivar(done, db_name)
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
      merge.merge(@location)
      merge.save if merge.changed?
      @location = merge
      flash_notice(:runtime_location_merge_success.t(this: old_name,
                                                     that: new_name))
      redirect_to(@location.show_link_args)
    else
      redirect_with_query(emails_merge_request_path(
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
      sender_email: @user.email,
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

  ##############################################################################

  def permitted_location_params
    params.require(:location).
      permit(:display_name, :north, :west, :east, :south, :high, :low, :notes)
  end
end
# rubocop:enable Metrics/ClassLength
