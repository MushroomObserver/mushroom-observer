# frozen_string_literal: true

class UpdateBoxAreaAndCenterColumnsJob < ApplicationJob
  queue_as :maintenance

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
    alert_on_missing_box_area(loc_count)
    # Return the values for debugging
    [loc_updated, obs_centered, obs_center_nulled]
  end

  private

  # box_area is computed when a Location is saved, so a nil is a data
  # anomaly - a location persisted through a path that bypassed it - not
  # routine backlog. Surface it after the repair (so this only fires on a
  # real run, not a dry-run inspection). A clean run stays silent.
  def alert_on_missing_box_area(loc_count)
    return unless loc_count.positive?

    alert("#{loc_count} location(s) have a nil box_area (expected 0) - a " \
          "location was saved without computing box_area. Repaired this " \
          "run; investigate the source if it recurs.")
  end
end
