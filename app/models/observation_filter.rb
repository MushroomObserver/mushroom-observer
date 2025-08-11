# frozen_string_literal: true

# Non-AR model for the faceted PatternSearch form.
class ObservationFilter < SearchFilter
  # Assign attributes from the PatternSearch::Observation.params hash,
  # adjusting for range fields and autocompleters with hidden id fields.
  PatternSearch::Observation.params.map do |keyword, values|
    case values[1]
    when :parse_date_range
      attribute(keyword, :string)
      attribute(:"#{keyword}_range", :string)
    when :parse_confidence
      attribute(keyword, :integer)
      attribute(:"#{keyword}_range", :integer)
    when :parse_longitude, :parse_latitude
      attribute(keyword, :float)
    when /parse_list_of_/
      attribute(keyword, :string)
      attribute(:"#{keyword}_id", :string)
    else
      attribute(keyword, :string)
    end
  end
end
