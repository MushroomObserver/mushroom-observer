# frozen_string_literal: true

# see app/controllers/locations_controller.rb
class LocationsController

  ##############################################################################
  #
  #  :section: New, Create, Edit, Update
  #
  ##############################################################################

  def new
    store_location
    pass_query_params

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

    # Render a blank form.
    user_name = Location.user_name(@user, @display_name)
    if @display_name
      @dubious_where_reasons = Location.
                               dubious_name?(user_name, true)
    end
    @location = Location.new
    geocoder = Geocoder.new(user_name)
    if geocoder.valid
      @location.display_name = @display_name
      @location.north = geocoder.north
      @location.south = geocoder.south
      @location.east = geocoder.east
      @location.west = geocoder.west
    else
      @location.display_name = ""
      @location.north = 80
      @location.south = -80
      @location.east = 89
      @location.west = -89
    end

  end

  alias_method :create_location, :new

  def create
    # Set to true below if created successfully, or if a matching location
    # already exists.  In either case, we're done with this form.
    done = false

    # Look to see if the display name is already in use.
    # If it is then just use that location and ignore the other values.
    # Probably should be smarter with warnings and merges and such...
    db_name = Location.user_name(@user, @display_name)
    @location = Location.find_by_name_or_reverse_name(db_name)

    # Location already exists.
    if @location
      flash_warning(:runtime_location_already_exists.t(name: @display_name))
      done = true

    # Need to create location.
    else
      @location = Location.new(whitelisted_location_params)
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
          flash_object_errors @location
        end
      end
    end

    # If done, update any observations at @display_name,
    # and set user's primary location if called from profile.
    if done
      if @original_name.present?
        db_name = Location.user_name(@user, @original_name)
        Observation.define_a_location(@location, db_name)
        SpeciesList.define_a_location(@location, db_name)
      end
      if @set_observation
        if unshown_notifications?(@user, :naming)
          redirect_to controller: :notifications, action: :show
        else
          # redirect_to(
          #   controller: :observations,
          #   action: :show,
          #   id: @set_observation
          # )
          redirect_to observation_path(@set_observation)
        end
      elsif @set_species_list
        # redirect_to(
        #   controller: :species_lists,
        #   action: :show,
        #   id: @set_species_list
        # )
        redirect_to species_list_path(@set_species_list)
      elsif @set_herbarium
        if (herbarium = Herbarium.safe_find(@set_herbarium))
          herbarium.location = @location
          herbarium.save
          # redirect_to(
          #   controller: :herbaria,
          #   action: :show,
          #   id: @set_herbarium
          # )
          redirect_to herbarium_path(@set_herbarium)
        end
      elsif @set_user
        if (user = User.safe_find(@set_user))
          user.location = @location
          user.save
          # redirect_to(
          #   controller: :users,
          #   action: :show,
          #   id: @set_user
          # )
          redirect_to user_path(@set_user)
        end
      else
        # redirect_to(
        #   controller: :locations,
        #   action: :show,
        #   id: @location.id
        # )
        redirect_to location_path(@location)
      end
    end
  end

  # :prefetch: :norobots:
  def edit
    store_location
    pass_query_params
    @location = find_or_goto_index(Location, params[:id].to_s)
    return unless @location

    params[:location] ||= {}
    @display_name = @location.display_name
  end

  alias_method :edit_location, :edit

  def update
    store_location
    pass_query_params
    @location = find_or_goto_index(Location, params[:id].to_s)
    @display_name = params[:location][:display_name].strip_squeeze
    db_name = Location.user_name(@user, @display_name)
    merge = Location.find_by_name_or_reverse_name(db_name)
    if merge && merge != @location
      update_location_merge(merge)
    else
      update_location_change(db_name)
    end
  end

  alias_method :post_edit_location, :update

  private

  # Merge this location with another.
  def update_location_merge(merge)
    if !@location.mergable? && merge.mergable?
      @location, merge = merge, @location
    end
    if in_admin_mode? || @location.mergable?
      merge.merge(@location)
      merge.save if merge.changed?
      @location = merge
      redirect_to(location_path(@location))
    else
      redirect_with_query(
        controller: :email,
        action: :email_merge_request,
        type: :Location,
        old_id: @location.id,
        new_id: merge.id
      )
    end
  end

  # Just change this location in place.
  def update_location_change(db_name)
    @dubious_where_reasons = []
    @location.notes = params[:location][:notes].to_s.strip
    @location.locked = params[:location][:locked] == "1" if in_admin_mode?
    if !@location.locked || in_admin_mode?
      @location.north = params[:location][:north] if params[:location][:north]
      @location.south = params[:location][:south] if params[:location][:south]
      @location.east  = params[:location][:east]  if params[:location][:east]
      @location.west  = params[:location][:west]  if params[:location][:west]
      @location.high  = params[:location][:high]  if params[:location][:high]
      @location.low   = params[:location][:low]   if params[:location][:low]
      @location.display_name = @display_name
      if @display_name != params[:approved_where]
        @dubious_where_reasons = Location.dubious_name?(db_name, true)
      end
    end
    return unless @dubious_where_reasons.empty?

    if !@location.changed?
      flash_warning(:runtime_edit_location_no_change.t)
      # redirect_to(
        # action: :show,
        # id: @location.id
      # )
      redirect_to location_path(@location.id)
    elsif !@location.save
      flash_object_errors(@location)
    else
      flash_notice(:runtime_edit_location_success.t(id: @location.id))
      # redirect_to(@location.show_link_args)
      redirect_to location_path(@location.id)
    end
  end

  public

  ##############################################################################
  #
  #  :section: Merging Locations
  #
  ##############################################################################

  # Show a list of defined locations that match a given +where+ string, in
  # order of closeness of match.
  def list_merge_options
    store_location
    @where = Location.user_name(@user, params[:where].to_s)

    # Split list of all locations into "matches" and "non-matches".  Try
    # matches in the following order:
    #   1) all that start with full "where" string
    #   2) all that start with everything in "where" up to the comma
    #   3) all that start with the first word in "where"
    #   4) there just aren't any matches, give up
    all = Location.all.order("name")
    @matches, @others = (
      split_out_matches(all, @where) ||
      split_out_matches(all, @where.split(",").first) ||
      split_out_matches(all, @where.split(" ").first) ||
      [nil, all]
    )
  end

  # Split up +list+ into those that start with +substring+ and those that
  # don't.  If none match, then return nil.
  def split_out_matches(list, substring)
    matches = list.select do |loc|
      (loc.name.to_s[0, substring.length] == substring)
    end
    if matches.empty?
      nil
    else
      [matches, list - matches]
    end
  end

  def reverse_name_order
    if (location = Location.safe_find(params[:id].to_s))
      location.name = Location.reverse_name(location.name)
      location.save
    end
    # redirect_to(
    #   action: :show,
    #   id: params[:id].to_s
    # )
    redirect_to location_path(params[:id].to_s)
  end

  # Adds the Observation's associated with <tt>obs.where == params[:where]</tt>
  # into the given Location.  Linked from +list_merge_options+, I think.
  def add_to_location
    location = find_or_goto_index(Location, params[:location])
    return unless location

    where = begin
              params[:where].strip_squeeze
            rescue StandardError
              ""
            end
    if where.present? &&
       update_observations_by_where(location, where)
      flash_notice(
        :runtime_location_merge_success.t(this: where,
                                          that: location.display_name)
      )
    end
    # redirect_to(
    #   action: :index
    # )
    redirect_to locations_path
  end

  # Help for locations
  def help; end

  # Move all the Observation's with a given +where+ into a given Location.
  def update_observations_by_where(location, given_where)
    success = true
    # observations = Observation.find_all_by_where(given_where)
    observations = Observation.where(where: given_where)
    count = 3
    observations.each do |o|
      count += 1
      next if o.location_id

      o.location_id = location.id
      o.where = nil
      unless o.save
        flash_error :runtime_location_merge_failed.t(name: o.unique_format_name)
        success = false
      end
    end
    success
  end

  ##############################################################################

  private

  def whitelisted_location_params
    params.require(:location).
      permit(:display_name, :north, :west, :east, :south, :high, :low, :notes)
  end

end
