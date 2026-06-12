# frozen_string_literal: true

# Action-nav for the location-descriptions index page. Replaces
# `Tabs::Locations::DescriptionsHelper#location_description_index_tabs`.
class Tab::LocationDescription::IndexActions < Tab::Collection
  def initialize(query: nil, q_param: nil, controller: nil)
    super()
    @query = query
    @q_param = q_param
    @controller = controller
  end

  private

  def tabs
    [
      Tab::Location::Map.new(q_param: @q_param),
      Tab::Location::Index.new,
      Tab::RelatedQuery.for(
        model: Location, filter: :LocationDescription,
        current_query: @query, controller: @controller
      )
    ].compact
  end
end
