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

  prop :target_id, String
  prop :open_text, _Nilable(String), default: nil
  prop :closed_text, _Nilable(String), default: nil
  prop :collapsed, _Boolean, default: true

  # `validate_no_btn_classes!` is called explicitly here since
  # declaring new props on this subclass makes Literal's generated
  # super chain skip Button's own hand-written initialize body (see
  # Button::CRUDBase for the same gotcha).
  def initialize(target_id:, **opts)
    extra_data  = opts.delete(:data) || {}
    opts[:data] = { toggle: "collapse",
                    target: "##{target_id}" }.merge(extra_data)
    validate_no_btn_classes!(opts[:class])
    super
  end

  private

  def merged_class
    class_names(super, "collapsed" => @collapsed)
  end

  def button_content
    collapse_content
  end
end
