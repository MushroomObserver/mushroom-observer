# frozen_string_literal: true

# Member-facing observation sub-tab: images related to the project's
# observation query. Wraps `Tab::RelatedQuery` (rather than reusing
# its instance directly) so the tab gets a stable `alt_title` for
# `ProjectNavs`/`NavTabs` active-tab matching -- `Tab::RelatedQuery`
# has no `alt_title`, and its demodulized-class-name fallback
# ("related_query") isn't a usable sub-tab key.
class Tab::Project::ObservationImages < Tab::Base
  def self.for(query:, controller:)
    related_query = ::Tab::RelatedQuery.for(
      model: ::Image, filter: :Observation,
      current_query: query, controller: controller
    )
    return nil unless related_query

    new(related_query: related_query)
  end

  def initialize(related_query:)
    super()
    @related_query = related_query
  end

  def title
    :images.ti
  end

  delegate :path, to: :@related_query

  def alt_title
    "images"
  end
end
