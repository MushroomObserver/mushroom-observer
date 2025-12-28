# frozen_string_literal: true

# Hidden fields for location bounds used by the map controller.
# Renders hidden inputs for north, south, east, west, low, and high values
# that the Stimulus map controller can read and update.
#
# Note: These fields are namespaced as location[north], location[south], etc.
# NOT nested under the parent form's model. This allows them to be handled
# separately for location creation/updates.
#
# @example Usage in a Phlex form
#   render(Components::BoundsHiddenFields.new(
#     location: @location,
#     target_controller: :map
#   ))
class Components::BoundsHiddenFields < Components::Base
  prop :location, _Nilable(Location), default: nil
  prop :target_controller, Symbol, default: :geocode

  BOUND_KEYS = %w[north south east west low high].freeze

  def view_template
    BOUND_KEYS.each { |key| render_bound_field(key) }
  end

  private

  def render_bound_field(key)
    value = @location&.send(key)
    input(
      type: "hidden",
      id: "location_#{key}",
      name: "location[#{key}]",
      value: value&.to_s,
      data: { "#{@target_controller}_target": "#{key}Input" }
    )
  end
end
