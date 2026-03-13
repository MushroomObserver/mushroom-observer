# frozen_string_literal: true

class UpdateBoxAreaAndCenterColumnsJob < ApplicationJob
  queue_as :default

  def perform(**args)
    args ||= {}
    log("Starting UpdateBoxAreaAndCenterColumnsJob.perform")
    # This should be zero, but count just in case.
    loc_count = Location.where(box_area: nil).count
    log("Found #{loc_count} locations without a box_area.")
    # Count the observations associated with locations that are under the
    # max area, but haven't got a center lat/lng, and log what we're updating.
    obs_count = Observation.in_box_of_max_area.where(location_lat: nil).count
    log("Found #{obs_count} observations where the associated location was " \
        "small enough, but the obs didn't have a location_lat/lng.")
    return [loc_count, obs_count] if args[:dry_run]

    # Do the update. This returns counts of locations/observations updated.
    loc_updated, obs_centered, obs_center_nulled =
      Location.update_box_area_and_center_columns

    log("Updated #{loc_updated} locations' box_area and center_lat/lng.")
    log("Updated #{obs_centered} observations' location_lat/lng.")
    log("Nulled #{obs_center_nulled} observations' location_lat/lng.")
    # Return the values for debugging
    [loc_updated, obs_centered, obs_center_nulled]
  end
end
