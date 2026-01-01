# frozen_string_literal: true

# Interactive map component for displaying locations and observations.
# Works with the Stimulus map controller to render Google Maps with
# markers and bounding boxes.
#
# Replaces the `make_map` helper from MapHelper.
#
# @example Basic usage
#   render(Components::Map.new(objects: [@location]))
#
# @example Editable map for forms
#   render(Components::Map.new(
#     objects: [@location],
#     editable: true,
#     map_type: "location",
#     controller: nil  # form has the controller
#   ))
#
class Components::Map < Components::Base
  include Phlex::Rails::Helpers::ContentTag
  include Phlex::Rails::Helpers::LinkTo

  prop :objects, _Array(_Any), default: -> { [] }
  prop :map_div, String, default: "map_div"
  prop :controller, _Nilable(String), default: "map"
  prop :map_target, String, default: "mapDiv"
  prop :map_type, String, default: "info"
  prop :need_elevations_value, _Boolean, default: true
  prop :map_open, _Boolean, default: true
  prop :editable, _Boolean, default: false
  prop :controls, _Array(Symbol), default: -> { [:large_map, :map_type] }
  prop :location_format, _Nilable(String), default: nil
  prop :nothing_to_map, _Nilable(String), default: nil
  prop :query_param, _Nilable(String), default: nil

  def view_template
    return render_nothing_to_map unless mappable_objects.any?

    render_map_container
  end

  private

  def mappable_objects
    @mappable_objects ||= @objects.reject do |obj|
      name = obj.respond_to?(:location) ? obj.location&.name : obj.name
      Location.is_unknown?(name)
    end
  end

  def nothing_to_map_text
    @nothing_to_map || :runtime_map_nothing_to_map.t
  end

  def render_nothing_to_map
    div(class: "w-100") { nothing_to_map_text }
  end

  def render_map_container
    div(class: "w-100 position-relative", style: "padding-bottom: 66%;") do
      div(id: @map_div, class: "position-absolute w-100 h-100",
          data: map_data_attributes)
    end
  end

  def map_data_attributes
    attrs = {
      map_target: @map_target,
      map_type: @map_type,
      need_elevations_value: @need_elevations_value,
      map_open: @map_open,
      editable: @editable,
      controls: @controls.to_json,
      location_format: @location_format || User.current_location_format,
      collection: mappable_collection.to_json,
      localization: localization_data.to_json
    }
    attrs[:controller] = @controller if @controller
    attrs
  end

  def localization_data
    {
      nothing_to_map: nothing_to_map_text,
      observations: :Observations.t,
      locations: :Locations.t,
      show_all: :show_all.t,
      map_all: :map_all.t
    }
  end

  def mappable_collection
    collection = Mappable::CollapsibleCollectionOfObjects.new(mappable_objects)
    collection.sets.each_value do |mapset|
      mapset.title = mapset_marker_title(mapset)
      mapset.caption = mapset_info_window(mapset)
      mapset.objects = nil
    end
    collection
  end

  # Title for map marker tooltip
  def mapset_marker_title(set)
    strings = map_location_strings(set.objects)
    result = if strings.length > 1
               "#{strings.length} #{:locations.t}"
             else
               strings.first
             end
    num_obs = set.observations.length
    if num_obs > 1 && num_obs != strings.length
      num_str = "#{num_obs} #{:observations.t}"
      result += strings.length > 1 ? ", #{num_str}" : " (#{num_str})"
    end
    result
  end

  def map_location_strings(objects)
    objects.filter_map do |obj|
      if obj.location?
        obj.display_name
      elsif obj.observation?
        if obj.location
          obj.location.display_name
        elsif obj.lat
          "#{format_latitude(obj.lat)} #{format_longitude(obj.lng)}"
        end
      end
    end.uniq
  end

  # Info window content for map marker popup
  def mapset_info_window(set)
    lines = []
    lines << observation_line(set)
    lines << location_line(set)
    lines << mapset_coords(set)
    lines.compact.join("<br>")
  end

  def observation_line(set)
    observations = set.observations
    return mapset_observation_header(set) if observations.length > 1
    return mapset_observation_link(observations.first) if single_obs?(set)

    nil
  end

  def single_obs?(set)
    set.observations.length == 1 && set.observations.first&.id
  end

  def location_line(set)
    locations = set.underlying_locations
    return mapset_location_header(set) if locations.length > 1
    return mapset_location_link(locations.first) if single_loc?(set)

    nil
  end

  def single_loc?(set)
    set.underlying_locations.length == 1 && set.underlying_locations.first&.id
  end

  def mapset_observation_header(set)
    count = set.observations.length
    "#{:Observations.t}: #{count}"
  end

  def mapset_location_header(set)
    count = set.underlying_locations.length
    "#{:Locations.t}: #{count}"
  end

  def mapset_observation_link(obs)
    url = observation_path(id: obs.id)
    "<a href=\"#{url}\">#{:Observation.t} ##{obs.id}</a>"
  end

  def mapset_location_link(loc)
    url = location_path(id: loc.id)
    "<a href=\"#{url}\">#{ERB::Util.html_escape(loc.display_name.t)}</a>"
  end

  def mapset_coords(set)
    if set.is_point
      "#{format_latitude(set.lat)}&nbsp;#{format_longitude(set.lng)}"
    else
      "<center>#{format_latitude(set.north)}<br>" \
        "#{format_longitude(set.west)}&nbsp;#{format_longitude(set.east)}<br>" \
        "#{format_latitude(set.south)}</center>"
    end
  end

  def format_latitude(val)
    format_coordinate(val, "N", "S")
  end

  def format_longitude(val)
    format_coordinate(val, "E", "W")
  end

  def format_coordinate(val, positive_dir, negative_dir)
    deg = val.abs.round(4)
    "#{deg}°#{val.negative? ? negative_dir : positive_dir}"
  end
end
