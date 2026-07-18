# frozen_string_literal: true

# Shared "how do lat/lng/alt display" formatting -- pure string
# presentation, no model/business logic. Mixed into Components::Base
# so Phlex views/components can call these directly, matching
# ViewerAwareFormat's precedent for presentational logic that used to
# live on individual models (Observation#display_lat_lng /
# #display_alt / #place_name_and_coordinates / #format_coordinate),
# and consolidating three more copies of the same format_coordinate /
# format_latitude / format_longitude algorithm that had accumulated
# independently in Mappable::ClusteredCollection, Components::Map,
# and Components::Map::Popup.
module CoordinateFormat
  # Full-precision (unrounded) lat/lng pair -- "34.1622°N 118.3521°W".
  def display_lat_lng(lat, lng)
    return "" unless lat

    "#{lat.abs}°#{lat.negative? ? "S" : "N"} " \
      "#{lng.abs}°#{lng.negative? ? "W" : "E"}"
  end

  def display_alt(alt)
    return "" unless alt

    "#{alt.round}m"
  end

  # place_name is a caller-supplied string (Observation#place_name,
  # Location#display_name, etc.) rather than computed here -- keeps
  # this module free of any dependency on a specific model's own
  # naming logic.
  def place_name_and_coordinates(place_name, lat, lng)
    return place_name unless lat.present? && lng.present?

    "#{place_name} (#{format_latitude(lat)} #{format_longitude(lng)})"
  end

  def format_latitude(val)
    format_coordinate(val, "N", "S")
  end

  def format_longitude(val)
    format_coordinate(val, "E", "W")
  end

  # Rounded-to-4-decimal-places coordinate, e.g. "34.1622°N".
  def format_coordinate(val, positive_dir, negative_dir)
    deg = val.abs.round(4)
    "#{deg}°#{val.negative? ? negative_dir : positive_dir}"
  end
end
