# frozen_string_literal: true

# list_merge_options
module Observations
  class LocationsController < ApplicationController
    before_action :login_required
    before_action :store_location, only: :edit

    ############################################################################
    #
    #  :section: Associate Observations with "undefined" +where+ strings
    #            to Location db records as a batch.
    #
    ############################################################################

    # NOTE: This "form" is only accessed from one index param,
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
    #   2) others that include everything in "where" up to the comma
    #   3) others that include the second-to-last segment in "where"
    #      (for example, "Plaza Garibaldi, Ciudad de Guadalajara, México":
    #      searches for "Ciudad de Guadalajara")
    #   4) others that include the last word of the first segment in "where"
    #      (for example, "Estado de Guerrero, México": searches for "Guerrero")
    #   5) others that include the first word in "where": "Estado"
    #   6) doesn't try other segments, because the last one could be a country
    #
    # The form is not really a `form`, but the buttons do commit to "update".
    # It contains links to assign the observations sharing the +where+ string
    # to the given Location (AR record)

    def edit
      # NOTE: Don't use or pass Location.user_format for @where. Needs "postal".
      # This is the string we're looking for in the db, in the `name` column,
      # and we're also assuming "postal" order when splitting the string.
      @where = params[:where].to_s
      @matches = locations_matching_where
      @pagination_data = paginate_locations!
    end

    # Adds the Observation's associated with obs.where == params[:where]
    # into the given Location.
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
          :runtime_location_merge_success.t(
            this: Location.user_format(@user, where),
            that: location.display_name
          )
        )
      end
      redirect_to(locations_path)
    end

    private

    def locations_matching_where
      matches = Location.name_has(@where)

      # Try for segments: split by comma, or by space if no commas
      places = @where.split(",")
      words = @where.split
      return matches unless places.length > 1 || words.length > 1

      matches += Location.name_has(places.first)
      # Try for specific segment matches if we have enough of them.
      if places.length > 2
        matches += Location.name_has(places.second_to_last.strip)
      end
      if places.length >= 2
        matches += Location.name_has(places.second_to_last.split.last)
      end
      matches += Location.name_has(words.first)

      matches.uniq
    end

    def paginate_locations!
      pages = number_pagination_data(:page, 100)
      pages.num_total = @matches.length
      @matches = @matches[pages.from..pages.to]
      pages
    end

    # Move all the Observation's with a given +where+ into a given Location.
    def update_observations_by_where(location, given_where)
      success = true
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
