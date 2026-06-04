# frozen_string_literal: true

# Generic "related index" link — appears on a filtered index of one
# model and points at the equivalent filtered index of a related
# model (e.g. "Images at these Locations" on a Locations index that
# was itself filtered from an Observation query). Wraps
# `InternalLink::RelatedQuery`.
#
# Use `.for(...)` to apply the `Query.related?(target, filter)`
# guard — returns nil when no bridge exists between filter and
# target. Call `.new(...)` directly only when the caller has
# already verified the bridge applies.
class Tab::Related::Query < Tab::Base
  def self.for(model:, filter:, current_query:, controller:)
    return nil unless current_query &&
                      ::Query.related?(model.name.to_sym, filter)

    new(model: model, filter: filter,
        current_query: current_query, controller: controller)
  end

  def initialize(model:, filter:, current_query:, controller:)
    super()
    @model = model
    @filter = filter
    @current_query = current_query
    @controller = controller
  end

  def to_internal_link
    @to_internal_link ||= ::InternalLink::RelatedQuery.new(
      @model, @filter, @current_query, @controller
    )
  end

  # `Tab::Related::Query` overrides `to_internal_link` rather than
  # implementing `path` directly (the URL is computed inside
  # `InternalLink::RelatedQuery`). Delegate `#path` to the
  # internal link's `#url` so callers that want just the URL —
  # e.g. `Tab::Related::Query.for(...)&.path` — work without
  # routing through `.to_a` and destructuring.
  def path
    to_internal_link.url
  end
end
