# frozen_string_literal: true

# Composite component for region search with bounding box map integration.
# Renders a region text field plus compass direction inputs for defining
# a geographic bounding box, integrated with a Stimulus map controller.
#
# @example Usage in SearchForm
#   RegionWithBoxFields(query: model, form_namespace: self)
class Components::RegionWithBoxFields < Components::Base
  include Phlex::Rails::Helpers::ClassNames

  register_output_helper :make_map

  prop :query, Query
  prop :form_namespace, _Any

  def view_template
    div(id: map_element_id, data: map_controller_data) do
      render_region_field
      render_in_box_fields
    end
  end

  private

  def map_element_id
    "region_map_controller"
  end

  def map_controller_data
    # Phlex converts underscores to dashes for symbol keys.
    # Use string "true" for correct JS comparison (dataset values are strings)
    { controller: "map", map_open: "true", need_elevations_value: false }
  end

  def render_region_field
    @form_namespace.autocompleter_field(
      :region,
      type: :region,
      label: "#{:REGION.t}:",
      value: @query&.region,
      button: :form_locations_find_on_map.l,
      button_data: { map_target: "showBoxBtn", action: "map#showBox" },
      controller_data: {
        autocompleter__region_map_outlet: "##{map_element_id}"
      },
      # Make text input a placeInput target so showBox() passes early return
      data: { map_target: "placeInput" },
      # Make hidden field a locationId target so mapLocationIdData() reads it
      hidden_data: { map_target: "locationId" }
    ) do |f|
      f.with_help { :form_regions_help.t }
    end
  end

  def render_in_box_fields
    @form_namespace.namespace(:in_box) do |in_box_ns|
      render_compass_inputs(in_box_ns)
      render_editable_map
    end
  end

  def render_compass_inputs(in_box_ns)
    render_compass_row(:north, in_box_ns)
    render_compass_row([:west, :east], in_box_ns)
    render_compass_row(:south, in_box_ns)
  end

  def render_compass_row(directions, in_box_ns)
    row_class = directions == :north ? "row vcenter" : "row vcenter mt-3"

    div(class: row_class) do
      if directions.is_a?(Array)
        render_east_west_row(directions, in_box_ns)
      else
        render_single_compass_input(directions, in_box_ns)
      end
    end
  end

  def render_east_west_row(directions, in_box_ns)
    render_compass_input(directions[0], in_box_ns, "col-xs-4")
    render_compass_help
    render_compass_input(directions[1], in_box_ns, "col-xs-4")
  end

  def render_single_compass_input(direction, in_box_ns)
    render_compass_input(direction, in_box_ns, "col-xs-4 col-xs-offset-4")
  end

  def render_compass_input(direction, in_box_ns, col_classes)
    div(class: col_classes) do
      field_component = in_box_ns.field(direction).text(
        wrapper_options: {
          label: "#{direction.upcase.to_sym.t}:",
          addon: "º"
        },
        value: box_value(direction),
        data: {
          map_target: "#{direction}Input",
          action: "map#bufferInputs"
        }
      )
      render(field_component)
    end
  end

  def render_compass_help
    div(class: "col-xs-4 small text-center p-0") do
      plain(:form_locations_lat_long_help.l)
    end
  end

  def box_value(direction)
    return 0.0 if @query&.in_box.blank?

    (@query.in_box[direction] || 0).to_f
  end

  # rubocop:disable Rails/OutputSafety
  def render_editable_map
    minimal_loc = build_minimal_location
    # make_map is a trusted helper that returns safe HTML
    raw(make_map(objects: [minimal_loc], editable: true, map_type: "location",
                 map_open: true, controller: nil))
  end
  # rubocop:enable Rails/OutputSafety

  def build_minimal_location
    args = if @query&.in_box.blank?
             { id: nil, name: nil, north: 0, south: 0, east: 0, west: 0 }
           else
             box = @query.in_box
             {
               id: nil, name: nil,
               north: box[:north] || 0,
               south: box[:south] || 0,
               east: box[:east] || 0,
               west: box[:west] || 0
             }
           end
    Mappable::MinimalLocation.new(**args)
  end
end
