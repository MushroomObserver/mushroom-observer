# frozen_string_literal: true

# Map component for location forms with toggle and clear buttons.
# Works with the Stimulus map controller to allow users to select locations
# visually on an interactive map.
#
# @example Basic usage in a Phlex form
#   render(Components::Form::LocationMap.new(
#     id: "herbarium_form_map",
#     map_type: "observation"
#   ))
class Components::Form::LocationMap < Components::Base
  prop :id, String, default: ""
  prop :map_type, String, default: "location"
  prop :user, _Nilable(User), default: nil

  def view_template
    render_map_div
    render_button_group
  end

  private

  def render_map_div
    CollapseDiv(
      id: @id,
      html_class: "form-map",
      attributes: { data: map_data_attributes }
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
    Button(
      type: :collapse_toggle,
      target_id: @id,
      open_text: :form_observations_hide_map.l,
      closed_text: :form_observations_open_map.l,
      icon: :globe,
      class: "map-toggle",
      data: { map_target: "toggleMapBtn",
              action: "map#toggleMap form-exif#showFields" },
      aria: { expanded: "false", controls: @id }
    )
  end

  def render_clear_button
    Button(
      name: :form_observations_clear_map.l,
      class: "map-clear",
      data: {
        map_target: "mapClearBtn",
        action: "map#clearMap form-exif#reenableButtons"
      }
    )
  end
end
