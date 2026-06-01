# frozen_string_literal: true

# Action-nav for the locations map page. Composes the back-to-index
# tab plus related-query bridges. Replaces
# `Tabs::LocationsHelper#location_map_tabs`.
class Tab::Location::MapActions < Tab::Collection
  def initialize(query: nil, controller: nil)
    super()
    @query = query
    @controller = controller
  end

  private

  def tabs
    [
      Tab::Location::Index.new,
      Tab::Related::Query.for(
        model: Observation, filter: :Location,
        current_query: @query, controller: @controller
      ),
      # related Locations bridge (cross-index for same model)
      Tab::Related::Query.for(
        model: Location, filter: :Location,
        current_query: @query, controller: @controller
      )
    ].compact
  end
end
