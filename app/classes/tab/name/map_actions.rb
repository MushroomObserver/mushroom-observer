# frozen_string_literal: true

# Action-nav for the name map page. A name-map query is, under the
# hood, an Observations-of-name query; "related records" therefore
# branch off the Observation query, not the Name.
class Tab::Name::MapActions < Tab::Collection
  def initialize(name:, query:, controller: nil)
    super()
    @name = name
    @query = query
    @controller = controller
  end

  private

  def tabs
    [
      Tab::Object::Show.new(object: @name,
                            title: :name_map_about.t(
                              name: @name.display_name
                            )),
      Tab::RelatedQuery.for(model: Location, filter: :Observation,
                              current_query: @query,
                              controller: @controller),
      Tab::RelatedQuery.for(model: Observation, filter: :Observation,
                              current_query: @query,
                              controller: @controller)
    ].compact
  end
end
