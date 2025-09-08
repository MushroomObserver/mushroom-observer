# frozen_string_literal: true

module FormLocationsHelper
  # The input for the location form, interacts with Stimulus map controller
  def form_location_input_find_on_map(form:, field:, value: nil, label: nil)
    text_field_with_label(
      form:, field:, value:, label:, help: :form_locations_help.t,
      data: { autofocus: true, map_target: "placeInput" },
      button: :form_locations_find_on_map.l,
      button_data: { map_target: "showBoxBtn", action: "map#showBox" }
    )
  end

  # This will generate a compass rose of inputs for given form object. The
  # inputs are for compass directions. The object can be a Location or a Box
  # (e.g. from query.in_box), that will prefill the values on load or reload.
  def form_compass_input_group(form:, obj:)
    capture do
      compass_groups.each do |dir|
        if compass_north_south.include?(dir)
          concat(compass_north_south_row(form, obj, dir))
        else
          concat(compass_east_west_row(form, obj, dir))
        end
      end
    end
  end

  def compass_north_south_row(form, obj, dir)
    tag.div(class: compass_row_classes(dir)) do
      compass_input(form, obj, dir, compass_col_classes(dir))
    end
  end

  def compass_east_west_row(form, obj, dir)
    tag.div(class: compass_row_classes(dir)) do
      [compass_input(form, obj, dir[0], compass_col_classes(dir[0])),
       compass_help,
       compass_input(form, obj, dir[1], compass_col_classes(dir[1]))].safe_join
    end
  end

  # Note these inputs are Stimulus map controller targets
  def compass_input(form, obj, dir, col_classes)
    tag.div(class: col_classes) do
      text_field_with_label(
        form:, field: dir, value: obj.send(dir),
        label: "#{dir.upcase.to_sym.t}:", addon: "º",
        data: { map_target: "#{dir}Input", action: "map#bufferInputs" }
      )
    end
  end

  def compass_help
    tag.div(class: "col-xs-4 small text-center p-0") do
      :form_locations_lat_long_help.l
    end
  end

  # This will change in Bootstrap 4. North gets less margin top
  def compass_row_classes(dir)
    if dir == :north
      "row vcenter"
    else
      "row vcenter mt-3"
    end
  end

  # This will change in Bootstrap 4
  def compass_col_classes(dir)
    if [:west, :east].include?(dir)
      "col-xs-4 text-center"
    else
      "col-xs-4 col-xs-offset-4 text-center"
    end
  end

  def compass_groups
    [:north, [:west, :east], :south].freeze
  end

  def compass_north_south
    [:north, :south].freeze
  end

  ##############################################################################
  # Elevation
  #
  def form_elevation_input_group(form:, obj:)
    tag.div(class: "text-center") do
      elevation_directions.each do |dir|
        concat(elevation_input(form, obj, dir))
      end
      concat(elevation_request_button)
    end
  end

  def elevation_input(form, obj, dir)
    text_field_with_label(
      form: form, field: dir, value: obj.send(dir),
      label: :"show_location_#{dir}est".t, addon: "m",
      data: { map_target: "#{dir}Input", action: "map#bufferInputs" }
    )
  end

  def elevation_directions
    [:high, :low].freeze
  end

  def elevation_request_button
    tag.button(
      :form_locations_get_elevation.l,
      type: :button, class: "btn btn-default",
      data: { map_target: "getElevation", action: "map#getElevations",
              map_points_param: "input", map_type_param: "rectangle" }
    )
  end
end
