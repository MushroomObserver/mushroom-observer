# frozen_string_literal: true

# add_to_location  --- NOTE: is this used?
module Locations
  class ObservationsController < ApplicationController
    before_action :login_required

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
