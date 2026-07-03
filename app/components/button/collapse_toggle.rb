# frozen_string_literal: true

# `<button>` collapse trigger — same API as `Link::CollapseToggle`
# but emits a `<button type="button">` instead of `<a>`. Use when the
# trigger is a non-navigational action wired to a Stimulus controller
# (e.g. the location-map open/close button).
#
# Dispatched via `Components::Button.new(type: :collapse_toggle, ...)`.
#
# @example Map expand/collapse toggle
#   Button(
#     type: :collapse_toggle,
#     target_id: "herbarium_form_map",
#     open_text: :form_observations_hide_map.l,
#     closed_text: :form_observations_open_map.l,
#     collapsed: true,
#     icon: :globe,
#     class: "map-toggle",
#     data: { map_target: "toggleMapBtn",
#             action: "map#toggleMap" },
#     aria: { expanded: "false", controls: "herbarium_form_map" }
#   )
class Components::Button::CollapseToggle < Components::Button
  include Components::Button::CollapseContent

  def initialize(target_id:, open_text: nil, closed_text: nil,
                 collapsed: true, **opts)
    @target_id   = target_id
    @open_text   = open_text
    @closed_text = closed_text
    @collapsed   = collapsed
    extra_data   = opts.delete(:data) || {}
    opts[:data]  = { toggle: "collapse",
                     target: "##{target_id}" }.merge(extra_data)
    super(**opts)
  end

  private

  def merged_class
    class_names(super, "collapsed" => @collapsed)
  end

  def button_content
    collapse_content
  end
end
