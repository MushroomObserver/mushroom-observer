# frozen_string_literal: true

# This requires Stimulus delaying the fetch until we have a complete word.
class AutoComplete::ForRegion < AutoComplete::ByWord
  attr_accessor :reverse

  def initialize(params)
    super
    self.reverse = (params[:format] == "scientific")
  end

  # Using observation.where gives the possibility of strings with no ID.
  # Trying to match "region" means matching the end of the postal format string.
  # "scientific" format users will have the country first, so reverse words
  def rough_matches(words)
    words = Location.reverse_name(words) if reverse
    regions = Observation.in_region(words).pluck(:where, :location_id)

    regions.map! do |reg, id|
      format = reverse ? Location.reverse_name(reg) : loc
      { name: format, id: id.nil? ? 0 : id }
    end
    # Sort by name and prefer those with a non-zero ID
    regions.sort_by! { |reg| [reg[:name], -reg[:id]] }
    regions.uniq { |reg| reg[:name] }
  end
end
