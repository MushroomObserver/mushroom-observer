# frozen_string_literal: true

# Elevation input group for location forms.
# Renders high and low elevation inputs with a button to fetch elevations
# from the map. Interacts with the Stimulus map controller.
#
# @example Usage in a form
#   FormElevationFields(form: f, location: @location)
#
class Components::FormElevationFields < Components::Base
  prop :form, Components::ApplicationForm
  prop :location, Location

  def view_template
    div(class: "text-center") do
      elevation_input(:high)
      elevation_input(:low)
      render_get_elevation_button
    end
  end

  private

  def elevation_input(direction)
    @form.text_field(
      direction,
      value: @location.send(direction)&.to_s,
      label: :"show_location_#{direction}est".t,
      addon: "m",
      wrap_class: "text-left",
      data: {
        map_target: "#{direction}Input",
        action: "map#bufferInputs"
      }
    )
  end

  def render_get_elevation_button
    button(
      type: :button,
      class: "btn btn-default",
      data: {
        map_target: "getElevation",
        action: "map#getElevations",
        map_points_param: "input",
        map_type_param: "rectangle"
      }
    ) { :form_locations_get_elevation.l }
  end
end
