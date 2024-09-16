# frozen_string_literal: true

# Non-AR model for the faceted PatternSearch form.
class ObservationFilter < SearchFilter
  # Assign attributes from the PatternSearch::Observation.params hash
  PatternSearch::Observation.params.map do |keyword, values|
    case values[1]
    when :parse_date_range
      attribute(keyword, :date)
      attribute(:"#{keyword}_range", :date)
    when :parse_confidence
      attribute(keyword, :integer)
    when :parse_longitude, :parse_latitude
      attribute(keyword, :float)
    else
      attribute(keyword, :string)
    end
  end
end
