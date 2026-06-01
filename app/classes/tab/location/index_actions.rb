# frozen_string_literal: true

# Action-nav for the locations index page. Replaces
# `Tabs::LocationsHelper#locations_index_tabs`.
class Tab::Location::IndexActions < Tab::Collection
  def initialize(query: nil, q_param: nil, controller: nil)
    super()
    @query = query
    @q_param = q_param
    @controller = controller
  end

  private

  def tabs
    [
      Tab::Location::New.new,
      Tab::Location::Map.new(q_param: @q_param),
      Tab::Location::Countries.new,
      Tab::Related::Query.for(
        model: Observation, filter: :Location,
        current_query: @query, controller: @controller
      )
    ].compact
  end
end
