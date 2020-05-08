# frozen_string_literal: true

# see app/controllers/locations_controller.rb
class LocationsController

  ##############################################################################
  #
  #  :section: Show Location
  #
  ##############################################################################

  # Show a Location and one of its LocationDescription's, including a map.
  def show
    store_location
    pass_query_params
    clear_query_in_session

    # Load Location and LocationDescription along with a bunch of associated
    # objects.
    loc_id = params[:id].to_s
    desc_id = params[:desc]
    @location = find_or_goto_index(Location, loc_id)
    return unless @location

    @canonical_url = "#{MO.http_domain}/locations/#{@location.id}"

    # Load default description if user didn't request one explicitly.
    desc_id = @location.description_id if desc_id.blank?
    if desc_id.blank?
      @description = nil
    elsif (@description = LocationDescription.safe_find(desc_id))
      @description = nil unless in_admin_mode? || @description.is_reader?(@user)
    else
      flash_error(:runtime_object_not_found.t(type: :description,
                                              id: desc_id))
    end

    update_view_stats(@location)
    update_view_stats(@description) if @description

    # Get a list of projects the user can create drafts for.
    @projects = @user&.projects_member&.select do |project|
      @location.descriptions.none? { |d| d.belongs_to_project?(project) }
    end
  end

  alias_method :show_location, :show

  # Show past version of Location.  Accessible only from show_location page.
  def show_past_location
    store_location
    pass_query_params
    @location = find_or_goto_index(Location, params[:id].to_s)
    return unless @location

    if params[:version]
      @location.revert_to(params[:version].to_i)
    else
      flash_error(:show_past_location_no_version.t)
      # redirect_to(
      #   action: :show,
      #   id: @location.id
      # )
      redirect_to @location
    end
  end

  # Go to next location: redirects to show_location.
  def show_next
    redirect_to_next_object(:next, Location, params[:id].to_s)
  end

  alias_method :next_location, :show_next

  # Go to previous location: redirects to show_location.
  def show_prev
    redirect_to_next_object(:prev, Location, params[:id].to_s)
  end

  alias_method :prev_location, :show_prev

end
