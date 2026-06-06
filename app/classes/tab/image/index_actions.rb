# frozen_string_literal: true

# Action-nav for the images index page. Carries the
# "Related Observations" bridge so users can pivot from this image
# query to the equivalent observation query.
class Tab::Image::IndexActions < Tab::Collection
  def initialize(query: nil, controller: nil)
    super()
    @query = query
    @controller = controller
  end

  private

  def tabs
    [
      Tab::RelatedQuery.for(
        model: Observation, filter: :Image,
        current_query: @query, controller: @controller
      )
    ].compact
  end
end
