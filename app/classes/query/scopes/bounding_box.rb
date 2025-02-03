# frozen_string_literal: true

# Helper methods for adding location extent conditions to query.
module Query::Scopes::BoundingBox
  def add_bounding_box_conditions_for_locations
    return unless (box = we_have_a_box?)

    @scopes = @scopes.where(Location.in_box(**box))
  end

  def add_bounding_box_conditions_for_observations
    return unless (box = we_have_a_box?)

    @scopes = @scopes.left_outer_joins(:location).where(
      use_observation_coordinates?.
      when(true).then(Observation.in_box(**box)).
      when(false).then(Location.in_box(**box))
    )
    add_join_to_locations
  end

  # ----------------------------------------------------------------------------

  def we_have_a_box?
    if params.values_at(:south, :north, :west, :east).all?(&:present?)
      params.select(:north, :south, :east, :west)
    else
      false
    end
  end

  def use_observation_coordinates?
    Location[:id].eq(nil).or(obs_lat_lng_plausible)
  end

  # Condition which returns true if the observation's lat/long is plausible
  # with respect to the location given.
  # (originally identical to Mappable::BoxMethods.lat_lng_close? but is not)
  def obs_lat_lng_plausible
    obs_lat_plausible.and(
      location_straddles_dateline.
        when(true).then(obs_lng_plausible_straddling_dateline).
        when(false).then(obs_lng_plausible)
    )
  end

  def obs_lat_plausible
    Observation[:lat].gteq(
      (Location[:south] * 1.2) - (Location[:north] * 0.2)
    ).and(
      Observation[:lat].lteq(
        (Location[:south] * 1.2) - (Location[:north] * 0.2)
      )
    )
  end

  def location_straddles_dateline
    Location[:west].gt(Location[:east])
  end

  def obs_lng_plausible
    Observation[:lng].gteq(
      (Location[:west] * 1.2) - (Location[:east] * 0.2)
    ).and(
      Observation[:lng].lteq(
        (Location[:east] * 1.2) - (Location[:west] * 0.2)
      )
    )
  end

  def obs_lng_plausible_straddling_dateline
    Observation[:lng].gteq(
      (Location[:west] * 0.8) - (Location[:east] * 0.2 + 72)
    ).or(
      Observation[:lng].lteq(
        (Location[:east] * 0.8) - (Location[:west] * 0.2 - 72)
      )
    )
  end
end
