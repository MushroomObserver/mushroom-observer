# frozen_string_literal: true

# Composite component for region search with bounding box map integration.
# Renders a region text field plus compass direction inputs for defining
# a geographic bounding box, integrated with a Stimulus map controller.
#
# @example Usage in SearchForm
#   render(Components::Form::RegionWithBoxFields.new(
#            query: model, form_namespace: self
#          ))
class Components::Form::RegionWithBoxFields < Components::Base
  prop :query, Query
  prop :form_namespace, ::Components::ApplicationForm

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
      label: :region.ti,
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
      render(Components::Form::CompassFields.new(
               field_source: in_box_ns, values: box_values
             ))
      render_editable_map
    end
  end

  def box_values
    [:north, :south, :east, :west].index_with { |dir| box_value(dir) }
  end

  def box_value(direction)
    return 0.0 if @query&.in_box.blank?

    (@query.in_box[direction] || 0).to_f
  end

  def render_editable_map
    Map(
      objects: [build_minimal_location],
      editable: true, map_type: "location",
      map_open: true, controller: nil
    )
  end

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
