# frozen_string_literal: true

# Map component for location forms with toggle and clear buttons.
# Works with the Stimulus map controller to allow users to select locations
# visually on an interactive map.
#
# @example Basic usage in a Phlex form
#   render(Components::FormLocationMap.new(
#     id: "herbarium_form_map",
#     map_type: "observation"
#   ))
class Components::FormLocationMap < Components::Base
  prop :id, String, default: ""
  prop :map_type, String, default: "location"
  prop :user, _Nilable(User), default: nil

  def view_template
    render_map_div
    render_button_group
  end

  private

  def render_map_div
    div(
      id: @id,
      class: "form-map collapse",
      data: map_data_attributes
    )
  end

  def map_data_attributes
    {
      indicator_url: asset_path("indicator.gif"),
      location_format: location_format,
      map_target: "mapDiv",
      editable: "true",
      map_type: @map_type
    }
  end

  def location_format
    @user&.location_format || "postal"
  end

  def render_button_group
    div(class: "btn-group my-3", role: "group",
        data: { map_target: "controlWrap" }) do
      render_toggle_button
      render_clear_button
    end
  end

  def render_toggle_button
    button(
      type: "button",
      name: "map_toggle",
      class: "btn btn-default map-toggle",
      data: toggle_button_data,
      aria: { expanded: "false", controls: @id }
    ) do
      link_icon(:globe)
      span(class: "map-show mx-2") { :form_observations_open_map.l }
      span(class: "map-hide mx-2") { :form_observations_hide_map.l }
    end
  end

  def toggle_button_data
    {
      map_target: "toggleMapBtn",
      action: "map#toggleMap form-exif#showFields",
      toggle: "collapse",
      target: "##{@id}"
    }
  end

  def render_clear_button
    button(
      type: "button",
      name: "map_clear",
      class: "btn btn-default map-clear",
      data: {
        map_target: "mapClearBtn",
        action: "map#clearMap form-exif#reenableButtons"
      }
    ) { :form_observations_clear_map.l }
  end
end
