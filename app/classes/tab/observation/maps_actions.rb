# frozen_string_literal: true

# Action-nav for the observations-map page. Two related-index
# bridges that branch off the current Observation query: back to
# the obs index, and to the locations index.
class Tab::Observation::MapsActions < Tab::Collection
  def initialize(query: nil, controller: nil)
    super()
    @query = query
    @controller = controller
  end

  private

  def tabs
    [
      Tab::Related::Query.for(model: Observation, filter: :Observation,
                              current_query: @query,
                              controller: @controller),
      Tab::Related::Query.for(model: Location, filter: :Observation,
                              current_query: @query,
                              controller: @controller)
    ].compact
  end
end
