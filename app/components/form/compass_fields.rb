# frozen_string_literal: true

# Compass rose input group: north, south, east, west coordinate
# inputs that interact with the Stimulus map controller. Shared by
# the location form (fields bound directly to a Location's
# coordinates) and Form::RegionWithBoxFields (fields bound under a
# search query's `in_box` sub-namespace).
#
# `field_source` is whatever Superform object `direction` should
# resolve a field against -- either the form itself or a
# `form.namespace(...)` proxy, the only two things in this app that
# answer `#field(name)`. `values` supplies each direction's current
# value explicitly, since neither caller's field is pre-bound to the
# value shown (the location form re-reads the model directly;
# `in_box` has no backing model attribute).
#
# @example Location form (fields bound directly to the model)
#   render(Components::Form::CompassFields.new(
#            field_source: self,
#            values: { north: location.north, south: location.south,
#                     east: location.east, west: location.west }
#          ))
#
# @example Search form (fields bound under an `in_box` namespace)
#   form.namespace(:in_box) do |in_box_ns|
#     render(Components::Form::CompassFields.new(
#              field_source: in_box_ns,
#              values: { north: 0.0, south: 0.0, east: 0.0, west: 0.0 }
#            ))
#   end
#
class Components::Form::CompassFields < Components::Base
  prop :field_source, _Union(Components::ApplicationForm, Superform::Namespace)
  prop :values, _Hash(Symbol, _Nilable(Numeric))

  def view_template
    render_north_row
    render_east_west_row
    render_south_row
  end

  private

  def render_north_row
    Row(class: "vcenter") do
      Column(xs: 4, offset_xs: 4, class: "text-center") do
        compass_input(:north)
      end
    end
  end

  def render_east_west_row
    Row(class: "vcenter") do
      Column(xs: 4, class: "text-center") { compass_input(:west) }
      Column(xs: 4, class: "text-center p-0") do
        small { plain(:form_locations_lat_long_help.l) }
      end
      Column(xs: 4, class: "text-center") { compass_input(:east) }
    end
  end

  def render_south_row
    Row(class: "vcenter") do
      Column(xs: 4, offset_xs: 4, class: "text-center") do
        compass_input(:south)
      end
    end
  end

  def compass_input(direction)
    render(@field_source.field(direction).text(
             wrapper_options: { label: direction.upcase.to_sym, addon: "º",
                                wrap_class: "text-left" },
             value: @values[direction].to_s,
             data: {
               map_target: "#{direction}Input",
               action: "map#bufferInputs"
             }
           ))
  end
end
