# frozen_string_literal: true

module BoxMethods
  def is_location?
    true
  end

  def is_observation?
    false
  end

  # Return [north, west].
  def north_west
    [north, west]
  end

  # Return [north, east].
  def north_east
    [north, east]
  end

  # Return [south, west].
  def south_west
    [south, west]
  end

  # Return [south, east].
  def south_east
    [south, east]
  end

  # Return center latitude.
  def lat
    (north + south) / 2.0
  rescue StandardError
    nil
  end

  # Return center longitude.
  def long
    long = (east + west) / 2.0
    long += 180 if west > east
    long
  rescue StandardError
    nil
  end

  # Return center as [lat, long].
  def center
    [lat, long]
  end

  # Returns [north, south, east, west].
  def edges
    [north, south, east, west]
  end

  # Returns north - south.
  def north_south_distance
    north - south
  end

  # Returns east - west (adjusting if straddles dateline).
  def east_west_distance
    west <= east ? east - west : east - west + 360
  end

  # Is a given lat/long coordinate within or close to the bounding box?
  def lat_long_close?(lat, long)
    delta_lat = north_south_distance * 0.20
    delta_long = east_west_distance * 0.20
    return false if lat > north + delta_lat
    return false if lat < south - delta_lat

    if west <= east
      return false if long > east + delta_long
      return false if long < west - delta_long
    else
      return false if long < west + delta_long && long > east - delta_long
    end
    true
  end
end
