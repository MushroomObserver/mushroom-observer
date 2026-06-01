# frozen_string_literal: true

# 3 related-index bridges (Locations / Names / Images) for the
# observations index when filtered by a Query. Replaces
# `Tabs::ObservationsHelper#observations_related_query_tabs`.
class Tab::Observation::RelatedQueryActions < Tab::Collection
  def initialize(query: nil, controller: nil)
    super()
    @query = query
    @controller = controller
  end

  private

  def tabs
    [
      Tab::Related::Query.for(model: Location, filter: :Observation,
                              current_query: @query,
                              controller: @controller),
      Tab::Related::Query.for(model: Name, filter: :Observation,
                              current_query: @query,
                              controller: @controller),
      Tab::Related::Query.for(model: Image, filter: :Observation,
                              current_query: @query,
                              controller: @controller)
    ].compact
  end
end
