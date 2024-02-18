# frozen_string_literal: true

# list_merge_options
module Observations
  class LocationsController < ApplicationController
    before_action :login_required

    ############################################################################
    #
    #  :section: Associate Observations with "undefined" +where+ strings
    #            to Location db records as a batch.
    #
    ############################################################################

    # NOTE: This "form" is only accessed from one index flavor,
    #       "OBSERVATIONS AT WHERE"
    #
    # It's a UI for Observations lacking a Location association in the db,
    # that share a particular "where" string. Multiple obs may share such a
    # "where" string. These are referred to as "undefined Locations" in the
    # code, but they're not really Locations at all, they're just strings that
    # have been entered by a User when creating an obs, that might help us find
    # a defined Location. Future Obs validations could force users to use known
    # locations, or to define a Location record before the obs, but we
    # currently allow this type of vagueness.
    #
    # What the list shows is a list of defined Locations that match the given
    # +where+ string, in order of closeness of match, in the following order:
    #   1) matches = match the string
    #   1) others that start with everything in "where" up to the comma
    #   2) others that start with the first word in "where"
    #   3) doesn't try other segments, because the second one could be a country
    #
    # The form is not really a `form` and does not commit to a "create" action.
    # It contains links to convert the observations sharing the +where+ string

    def edit
      store_location
      @where = Location.user_format(@user, params[:where].to_s)
      @matches = Location.name_includes(@where)
      @others = []

      # Try for segments: split by comma, or by space if no commas
      places = @where.split(",")
      words = @where.split
      return unless places.length > 1 || words.length > 1

      @others = Location.name_includes(places.first).
                or(Location.name_includes(words.first))
    end

    # merges_controller_test
    # Adds the Observation's associated with obs.where == params[:where]
    # into the given Location.  Linked from +list_merge_options+, I think.
    def update
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
      redirect_to(locations_path)
    end

    private

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
        next if o.save

        flash_error(
          :runtime_location_merge_failed.t(name: o.unique_format_name)
        )
        success = false
      end
      success
    end
  end
end
