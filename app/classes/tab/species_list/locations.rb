# frozen_string_literal: true

# "N Locations" link on the species-list show page's action-tab
# strip. Delegates URL-building to `Tab::RelatedQuery` (the Location-
# via-Observation bridge query), but keeps a plain title -- `Tab::
# RelatedQuery#title` ("Show Locations") reads like an instruction,
# not a tab label, next to this row's other plain nouns (Map,
# Observations, Names, Images).
class Tab::SpeciesList::Locations < Tab::Base
  def initialize(query:, controller:, count: nil)
    super()
    @related = Tab::RelatedQuery.new(
      model: Location, filter: :Observation,
      current_query: query, controller: controller
    )
    @count = count
  end

  def title
    return :locations.ti unless @count

    "#{@count} #{:locations.ti}"
  end

  delegate :path, to: :@related

  def alt_title
    "locations"
  end
end
