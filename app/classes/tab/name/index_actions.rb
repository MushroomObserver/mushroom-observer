# frozen_string_literal: true

# Action-nav for the names index page. New + (All — when the
# current query is filtered to `has_observations`) +
# Related::Query(Observation, :Name).
class Tab::Name::IndexActions < Tab::Collection
  def initialize(query: nil, controller: nil)
    super()
    @query = query
    @controller = controller
  end

  private

  def tabs
    [
      Tab::Name::New.new,
      all_tab,
      Tab::RelatedQuery.for(model: Observation, filter: :Name,
                            current_query: @query,
                            controller: @controller)
    ].compact
  end

  def all_tab
    return unless @query&.params&.dig(:has_observations)

    Tab::Name::All.new
  end
end
