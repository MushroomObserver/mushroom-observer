# frozen_string_literal: true

# Helper methods for adding location extent conditions to query.
module Query::Scopes::BoundingBox
  def add_bounding_box_conditions_for_locations
    return unless params[:north] && params[:south] &&
                  params[:east] && params[:west]

    _, cond2 = bounding_box_conditions
    @where += cond2
  end

  def add_bounding_box_conditions_for_observations
    return unless params[:north] && params[:south] &&
                  params[:east] && params[:west]

    cond1, cond2 = bounding_box_conditions
    cond0 = lat_lng_plausible
    cond1 = cond1.join(" AND ")
    cond2 = cond2.join(" AND ")
    @where << "IF(locations.id IS NULL OR #{cond0}, #{cond1}, #{cond2})"
    add_join_to_locations
  end

  # ----------------------------------------------------------------------------

  # Condition which returns true if the observation's lat/long is plausible.
  # (should be identical to Mappable::BoxMethods.lat_lng_close? but is not)
  def lat_lng_plausible
    # %(
    #   observations.lat >= locations.south*1.2 - locations.north*0.2 AND
    #   observations.lat <= locations.north*1.2 - locations.south*0.2 AND
    #   if(locations.west <= locations.east,
    #     observations.lng >= locations.west*1.2 - locations.east*0.2 AND
    #     observations.lng <= locations.east*1.2 - locations.west*0.2,
    #     observations.lng >= locations.west*0.8 + locations.east*0.2 + 72 OR
    #     observations.lng <= locations.east*0.8 + locations.west*0.2 - 72
    #   )
    # )
    Observation[:lat].gteq(
      (Location[:south] * 1.2) - (Location[:north] * 0.2)
    ).and(
      Observation[:lat].gteq(
        (Location[:south] * 1.2) - (Location[:north] * 0.2)
      )
    ).and(
      Location[:west].lteq(Location[:east]).
      when(true).then(
        Observation[:lng].gteq(
          (Location[:west] * 1.2) - (Location[:east] * 0.2)
        ).and(
          Observation[:lng].lteq(
            (Location[:east] * 1.2) - (Location[:west] * 0.2)
          )
        )
      ).when(false).then(
        Observation[:lng].gteq(
          (Location[:west] * 0.8) - (Location[:east] * 0.2 + 72)
        ).or(
          Observation[:lng].lteq(
            (Location[:east] * 0.8) - (Location[:west] * 0.2 - 72)
          )
        )
      )
    )
  end

  def bounding_box_conditions
    n, s, e, w = params.values_at(:north, :south, :east, :west)
    if w < e
      bounding_box_normal(n, s, e, w)
    else
      bounding_box_straddling_date_line(n, s, e, w)
    end
  end

  def bounding_box_normal(north, south, east, west)
    [
      [
        # point location inside target box
        "observations.lat >= #{south}",
        "observations.lat <= #{north}",
        "observations.lng >= #{west}",
        "observations.lng <= #{east}"
      ], [
        # box entirely within target box
        "locations.south >= #{south}",
        "locations.north <= #{north}",
        "locations.west >= #{west}",
        "locations.east <= #{east}",
        "locations.west <= locations.east"
      ]
    ]
  end

  def bounding_box_straddling_date_line(north, south, east, west)
    [
      [
        # point location inside target box
        "observations.lat >= #{south}",
        "observations.lat <= #{north}",
        "(observations.lng >= #{west} OR observations.lng <= #{east})"
      ], [
        # box entirely within target box
        "locations.south >= #{south}",
        "locations.north <= #{north}",
        "locations.west >= #{west}",
        "locations.east <= #{east}",
        "locations.west > locations.east"
      ]
    ]
  end
end
