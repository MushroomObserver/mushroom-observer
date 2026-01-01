# frozen_string_literal: true

# Compass rose input group for location forms.
# Renders north, south, east, west coordinate inputs that interact with
# the Stimulus map controller.
#
# @example Usage in a form
#   FormCompassFields(form: f, location: @location)
#
class Components::FormCompassFields < Components::Base
  prop :form, Components::ApplicationForm
  prop :location, Location

  def view_template
    render_north_row
    render_east_west_row
    render_south_row
  end

  private

  def render_north_row
    div(class: "row vcenter") do
      div(class: "col-xs-4 col-xs-offset-4 text-center") do
        compass_input(:north)
      end
    end
  end

  def render_east_west_row
    div(class: "row vcenter mt-3") do
      div(class: "col-xs-4 text-center") { compass_input(:west) }
      div(class: "col-xs-4 small text-center p-0") do
        plain(:form_locations_lat_long_help.l)
      end
      div(class: "col-xs-4 text-center") { compass_input(:east) }
    end
  end

  def render_south_row
    div(class: "row vcenter mt-3") do
      div(class: "col-xs-4 col-xs-offset-4 text-center") do
        compass_input(:south)
      end
    end
  end

  def compass_input(direction)
    @form.text_field(
      direction,
      value: @location.send(direction).to_s,
      label: "#{direction.upcase.to_sym.t}:",
      data: {
        map_target: "#{direction}Input",
        action: "map#bufferInputs"
      }
    ) do |f|
      f.with_append { "º" }
    end
  end
end
