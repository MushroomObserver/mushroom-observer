# Helper methods for adding location extent conditions to query.
module Query::Modules::BoundingBox
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
    cond0 = lat_long_plausible
    cond1 = cond1.join(" AND ")
    cond2 = cond2.join(" AND ")
    @where << "IF(locations.id IS NULL OR #{cond0}, #{cond1}, #{cond2})"
    add_join_to_locations!
  end

  # ----------------------------------------------------------------------------

  def lat_long_plausible
    # Condition which returns true if the observation's lat/long is plausible.
    # (should be identical to BoxMethods.lat_long_close?)
    %(
      observations.lat >= locations.south*1.2 - locations.north*0.2 AND
      observations.lat <= locations.north*1.2 - locations.south*0.2 AND
      if(locations.west <= locations.east,
        observations.long >= locations.west*1.2 - locations.east*0.2 AND
        observations.long <= locations.east*1.2 - locations.west*0.2,
        observations.long >= locations.west*0.8 + locations.east*0.2 + 72 OR
        observations.long <= locations.east*0.8 + locations.west*0.2 - 72
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
        "observations.long >= #{west}",
        "observations.long <= #{east}"
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
        "(observations.long >= #{west} OR observations.long <= #{east})"
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
