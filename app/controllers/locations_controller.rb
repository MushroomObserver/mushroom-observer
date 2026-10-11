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
# rubocop:disable-next Metrics/ClassLength
class LocationsController < ApplicationController
  include ::Locationable

  before_action :store_location, except: [:index, :destroy]
  before_action :login_required

  ##############################################################################
  # INDEX
  #
  def index
    build_index_with_query
  end

  # Browsing all locations defaults to most-recently-modified first; a
  # filtered/search index (by_user, region, pattern, etc.) doesn't call
  # this and falls back to `Query::Locations.default_order` (alphabetical)
  # instead.
  def unfiltered_index_opts
    { query_args: { order_by: :updated_at }, display_opts: {} }.freeze
  end

  # Sort options for the index page. Swaps `updated_at` for
  # `rss_log` when the active query orders by rss_log. Read by
  # `add_sorter` in the view. Each key must resolve to
  # `Location.order_by_<key>`.
  def index_sort_options
    rss_log = @query&.params&.dig(:order_by) == "rss_log"
    [
      ["name",                               :sort_by_name.t],
      ["created_at",                         :sort_by_created_at.t],
      [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t],
      ["num_views",                          :sort_by_num_views.t],
      ["box_area",                           :sort_by_box_area.t]
    ]
  end

  ##############################################################################

  # Show a Location and one of its LocationDescription's, including a map.
  def show
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, Location, params[:id].to_s)
    when "prev"
      redirect_to_next_object(:prev, Location, params[:id].to_s)
    end
    return if performed?

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

    @versions = @location.versions.to_a
    # Save two lookups in comments_for_object
    @comments = @location.comments&.sort_by(&:created_at)&.reverse
    @desc_comments = @description&.comments&.sort_by(&:created_at)&.reverse
    init_projects_ivar
    render_show_view
  end

  def new
    init_caller_ivars_for_new

    # Render a blank form.
    if @display_name
      @dubious_where_reasons = Location.dubious_reasons_for(
        user: @user, place_name: @display_name
      )
    end
    @location = Location.new

    respond_to do |format|
      format.turbo_stream { render_modal_location_form }
      format.html { render_new_view }
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
      done = create_location_ivar_and_save(done)
    end

    # If done, update any observations at @display_name,
    # and set user's primary location if called from profile.
    return render_new_view_invalid unless done

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
    @display_name = @location.display_name(@user)

    respond_to do |format|
      format.turbo_stream { render_modal_location_form }
      format.html { render_edit_view }
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
      update_location_change
    end
  end

  def destroy
    return unless find_location!
    return unless can_destroy_location?

    # Refetch as a fresh (non-strict_loading) record so the destroy
    # cascade can reach `:project_aliases` (not in `show_includes`)
    # without lazy-load violations.
    if Location.find(@location.id).destroy
      flash_notice(:runtime_destroyed_id.t(type: :location, value: params[:id]))
    end
    redirect_to(locations_path)
  end

  def can_destroy_location?
    unless @location.destroyable?
      flash_error(:destroy_location_has_associations.t)
      redirect_to(location_path(@location))
      return false
    end
    unless in_admin_mode? || @location.user == @user
      flash_error(:permission_denied.t)
      redirect_to(location_path(@location))
      return false
    end
    true
  end

  ##############################################################################

  def find_location!
    @location = Location.show_includes.safe_find(params[:id]) ||
                flash_error_and_goto_index(Location, params[:id])
  end

  def render_show_view
    render(Views::Controllers::Locations::Show.new(
             location: @location,
             description: @description,
             versions: @versions,
             comments: @comments.to_a,
             projects: @projects
           ))
  end

  def render_index_view
    locations = @objects.to_a
    render(Views::Controllers::Locations::Index.new(
             query: @query, locations: locations,
             pagination_data: @pagination_data,
             observation_counts: known_observation_counts(locations)
           ))
  end

  # Per-location observation counts for the left "known places" panel.
  # Mirrors `attach_undef_counts`: a single aggregated count query
  # against the page's paginated set, because `Query#paginate`
  # rehydrates by ID and would strip any count column we put on the
  # base Location query.
  def known_observation_counts(locations)
    list = species_list_filter_for(@query)
    base = ::Observation.where(location: locations)
    base = base.joins(:species_lists).where(species_lists: { id: list }) if list
    base.group(:location_id).count
  end

  # If the query was filtered down to a single species list, only
  # count observations belonging to that list.
  def species_list_filter_for(query)
    return nil unless query.respond_to?(:params)
    return nil unless query.params.is_a?(Hash)

    obs_query = query.params[:observation_query]
    return nil unless obs_query.is_a?(Hash)

    species_lists = obs_query[:species_lists]
    return nil unless species_lists.is_a?(Array)
    return nil unless species_lists.length == 1

    ::SpeciesList.safe_find(species_lists[0])
  end

  def render_new_view(status: :ok, **render_opts)
    render(Views::Controllers::Locations::New.new(
             location: @location,
             display_name: @display_name,
             original_name: @original_name,
             set_observation: @set_observation,
             set_species_list: @set_species_list,
             set_user: @set_user,
             set_herbarium: @set_herbarium,
             set_project: @set_project,
             dubious_where_reasons: @dubious_where_reasons
           ), status: status, **render_opts)
  end

  def render_edit_view(status: :ok, **render_opts)
    render(Views::Controllers::Locations::Edit.new(
             location: @location,
             display_name: @display_name,
             dubious_where_reasons: @dubious_where_reasons
           ), status: status, **render_opts)
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
    @original_name = string_param(:where)

    # This is the latest value of place name.
    @display_name = begin
                      params[:location][:display_name].strip_squeeze
                    rescue StandardError
                      @original_name
                    end

    # Where to return after successfully creating location.
    set_params = params.permit(:set_observation, :set_species_list,
                               :set_user, :set_herbarium, :set_project)
    @set_observation  = set_params[:set_observation]
    @set_species_list = set_params[:set_species_list]
    @set_user         = set_params[:set_user]
    @set_herbarium    = set_params[:set_herbarium]
    @set_project      = set_params[:set_project]
  end

  def create_location_ivar_and_save(done)
    @location = Location.new(permitted_location_params)
    @location.current_user = @user
    @location.display_name = @display_name # (strip_squozen)

    # Validate name.
    @dubious_where_reasons = dubious_where_reasons_for(@display_name)

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

  # Every branch validates its id via `safe_find` (not just presence)
  # before redirecting, and always falls through to the next
  # candidate -- and ultimately to the location itself -- rather than
  # issuing no redirect at all for a stale or tampered set_* id.
  def return_to_caller
    if (observation = Observation.safe_find(@set_observation))
      redirect_to(permanent_observation_path(observation))
    elsif (species_list = SpeciesList.safe_find(@set_species_list))
      redirect_to(species_list_path(species_list))
    elsif (herbarium = Herbarium.safe_find(@set_herbarium))
      attach_location_and_redirect(herbarium, herbarium_path(herbarium))
    elsif (user = User.safe_find(@set_user))
      attach_location_and_redirect(user, user_path(user))
    elsif (project = Project.safe_find(@set_project))
      attach_location_and_redirect(project, project_path(project))
    else
      redirect_to(location_path(@location.id))
    end
  end

  def attach_location_and_redirect(record, path)
    record.location = @location
    record.save
    redirect_to(path)
  end

  # Merge this location with another.
  def update_location_merge(merge)
    if !@location.mergable? && merge.mergable?
      @location, merge = merge, @location
    end
    if in_admin_mode? || @location.mergable?
      old_name = @location.display_name(@user)
      new_name = merge.display_name(@user)
      merge.merge(@user, @location)
      merge.current_user = @user
      merge.save if merge.changed?
      @location = merge
      flash_notice(:runtime_location_merge_success.t(this: old_name,
                                                     that: new_name))
      redirect_to(@location.show_link_args)
    else
      # Explicit `format: :html`: see the matching comment in
      # HerbariaController#redirect_to_create_location -- the target
      # action's `respond_to` picks `format.turbo_stream` by Accept
      # header alone, and this redirect can be reached from a
      # Turbo-submitted form (see #5055).
      redirect_to(
        new_admin_emails_merge_requests_path(
          type: :Location, old_id: @location.id, new_id: merge.id,
          format: :html
        )
      )
    end
  end

  # Just change this location in place.
  def update_location_change
    @dubious_where_reasons = []
    @location.current_user = @user
    @location.notes = params[:location][:notes].to_s.strip
    @location.locked = params[:location][:locked] == "1" if in_admin_mode?
    determine_and_check_location if !@location.locked || in_admin_mode?
    return render_edit_view_invalid unless @dubious_where_reasons.empty?

    save_flash_and_redirect_or_render!
  end

  def determine_and_check_location
    @location.north = params[:location][:north] if params[:location][:north]
    @location.south = params[:location][:south] if params[:location][:south]
    @location.east  = params[:location][:east]  if params[:location][:east]
    @location.west  = params[:location][:west]  if params[:location][:west]
    @location.high  = params[:location][:high]  if params[:location][:high]
    @location.low   = params[:location][:low]   if params[:location][:low]
    @location.display_name = @display_name
    @dubious_where_reasons = dubious_where_reasons_for(@display_name)
  end

  def save_flash_and_redirect_or_render!
    @location.current_user = @user

    if !@location.changed?
      flash_warning(:runtime_edit_location_no_change.t)
      redirect_to(location_path(@location.id))
    elsif !@location.save
      flash_object_errors(@location)
      render_edit_view_invalid
    else
      flash_notice(:runtime_edit_location_success.t(id: @location.id))
      redirect_to(location_path(@location.id))
    end
  end

  def nontrivial_location_change?
    old_name = @location.display_name(@user)
    new_name = @display_name
    new_name.percent_match(old_name) < 0.9
  end

  def email_admin_location_change
    # Migrated from QueuedEmail::Webmaster to ActionMailer + ActiveJob.
    message = WebmasterMailer.prepend_user(@user, email_location_change_content)
    WebmasterMailer.build(
      sender_email: @user.email,
      subject: "Nontrivial Location Change",
      message:
    ).deliver_later
  end

  def email_location_change_content
    :email_location_change.l(
      user: @user.login,
      old: @location.display_name(@user),
      new: @display_name,
      observations: @location.observations.length,
      show_url: "#{MO.http_domain}/locations/#{@location.id}",
      edit_url: "#{MO.http_domain}/locations/#{@location.id}/edit"
    )
  end

  def render_modal_location_form
    render(Components::Modal.new(
             type: :turbo_form,
             identifier: modal_identifier,
             title: modal_title,
             user: @user,
             model: @location,
             form_locals: { display_name: @display_name }
           ), layout: false) and return
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
      :create_object.t(type: :location)
    when "edit", "update"
      render_to_string(Views::Layouts::Header::ObjectTitle.new(
                         object: @location, mode: :edit,
                         title: @location.display_name(@user)
                       ))
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
