# frozen_string_literal: true

# Non-AR model for the faceted PatternSearch form.
class NameFilter < SearchFilter
  # Assign attributes from the PatternSearch::Observation.params hash,
  # adjusting for range fields and autocompleters with hidden id fields.
  PatternSearch::Name.params.map do |keyword, values|
    case values[1]
    when :parse_date_range
      attribute(keyword, :date)
      attribute(:"#{keyword}_range", :date)
    when :parse_rank_range
      attribute(keyword, :string)
      attribute(:"#{keyword}_range", :string)
    else
      attribute(keyword, :string)
    end
  end
end
