# frozen_string_literal: true

# Generic "related index" link — appears on a filtered index of one
# model and points at the equivalent filtered index of a related
# model (e.g. "Images at these Locations" on a Locations index that
# was itself filtered from an Observation query).
#
# Use `.for(...)` to apply the `Query.related?(target, filter)`
# guard — returns nil when no bridge exists between filter and
# target. Call `.new(...)` directly only when the caller has
# already verified the bridge applies.
#
# Inherits `Tab::QueryLink`'s memoized `#query` + `#path` =
# `controller.add_q_param(target_params, query)`. Subclass-side
# state: the model + filter + current_query that drive the
# `Query.current_or_related_query(...)` bridge.
class Tab::RelatedQuery < Tab::QueryLink
  def self.for(model:, filter:, current_query:, controller:)
    return nil unless current_query &&
                      ::Query.related?(model.name.to_sym, filter)

    new(model: model, filter: filter,
        current_query: current_query, controller: controller)
  end

  def initialize(model:, filter:, current_query:, controller:)
    super(controller: controller)
    @model = model
    @filter = filter
    @current_query = current_query
  end

  def title
    :show_objects.t(type: @model.type_tag)
  end

  private

  def build_query
    ::Query.current_or_related_query(
      @model.name.to_sym, @filter, @current_query
    )
  end

  def target_params
    { controller: @model.show_controller, action: @model.index_action }
  end
end
