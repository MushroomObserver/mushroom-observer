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
class Tab::RelatedQuery < Tab::Base
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

  def title
    :show_objects.t(type: @model.type_tag)
  end

  def path
    @controller.add_q_param(
      { controller: @model.show_controller, action: @model.index_action },
      ::Query.current_or_related_query(
        @model.name.to_sym, @filter, @current_query
      )
    )
  end
end
