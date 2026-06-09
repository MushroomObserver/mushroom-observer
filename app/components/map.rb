# frozen_string_literal: true

# Interactive map component for displaying locations and observations.
# Works with the Stimulus map controller to render Google Maps with
# markers and bounding boxes.
#
# Ports the logic that previously lived in `MapHelper`,
# `MapPopupHelper`, and `MapLegendHelper` so that those helpers can be
# deleted. The popup markup is the richer (`#4131`) flavor: a Bootstrap
# `.media` layout with a thumbnail for single-obs popups, and a header
# with "Show All" / "Map All" buttons for group popups.
#
# The rendering logic is split across three nested modules to keep
# `Metrics/ClassLength` in check:
#
#   * `Components::Map::Clustering` — Mappable::Clustered vs
#                                    CollapsibleCollection selection +
#                                    cluster_url / singleton_key.
#   * `Components::Map::Popup`      — info-window HTML (single-obs +
#                                    group), coordinate formatting.
#   * `Components::Map::Legend`     — border / consensus-color legend
#                                    rendered under the map container.
#
# All three are `include`d into `Components::Map` at the bottom of the
# class body. Their methods are all private and rely on instance
# variables (`@objects`, `@clustering`, `@query_param`, etc.) declared
# as props on the host class.
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
# @example Clustered observations map with cap banner
#   render(Components::Map.new(
#     objects: @observations,
#     clustering: true,
#     capped: @observations_capped,
#     cluster_query_string: @cluster_query_string,
#     query_param: q_param(@query),
#     zoom: 2,
#     observations_loaded_count: @observations_loaded_count,
#     observations_total_count: @observations_total_count
#   ))
#
class Components::Map < Components::Base
  # `<center>` is deprecated HTML but the Google Maps popup historically
  # relied on it to vertically stack the bounding-box coordinate lines.
  # Phlex doesn't ship it as a standard element; register it inline so
  # the popup markup stays byte-for-byte equivalent to the helper-era
  # output.
  register_element :center

  MAX_GROUP_NAMES = 3

  # Upper bound on points for client-side dynamic clustering
  # (issue #4159). Above this size we fall back to the server-side
  # CollapsibleCollectionOfObjects, which buckets the input
  # geographically into a manageable number of marker sets.
  CLUSTER_MAX_OBJECTS = 10_000

  # Mappable: real AR records (Location, Observation) or their
  # `Mappable::Minimal*` analogs used by index/maps endpoints.
  prop :objects, _Array(_Union(::Location, ::Observation,
                               ::Mappable::MinimalLocation,
                               ::Mappable::MinimalObservation)),
       default: -> { [] }
  prop :user, _Nilable(User), default: nil
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
  # Typed `Query` (not raw Hash). Used for URL minting in popup
  # links and by the `Mappable::ClusteredCollection` builder. Falls
  # back to `current_query` (controller's session-current query,
  # already validated by `query_from_q_param`) when omitted, so
  # chrome-y callers don't have to thread it through.
  prop :query, _Nilable(::Query), default: nil
  # Dynamic-clustering toggle. When true AND the input fits under
  # CLUSTER_MAX_OBJECTS, emit a Mappable::ClusteredCollection (one
  # MapSet per object) and `data-clustering="true"`, which tells the
  # JS controller to wrap the markers in a MarkerClusterer.
  prop :clustering, _Boolean, default: false
  # Whether the server-side dataset was capped (so the client knows to
  # refetch on viewport changes). Drives the cap-banner visibility.
  prop :capped, _Boolean, default: false
  # Server-emitted "q[...]=…" base for cluster popup Show All / Map All
  # links. The JS controller can't rebuild this from window.location
  # alone (might be a saved-query id, or no q params at all).
  prop :cluster_query_string, _Nilable(String), default: nil
  # Initial zoom level forwarded to the JS via data-zoom.
  prop :zoom, _Nilable(Integer), default: nil
  # Counts shown in the cap-banner — meaningful only when clustering.
  prop :observations_loaded_count, _Nilable(Integer), default: nil
  prop :observations_total_count, _Nilable(Integer), default: nil

  def view_template
    # Cap banner is part of the clustering chrome — render even when
    # there are no observations to map, so the JS layer can flip it
    # visible after a refetch returns capped results.
    render_cap_banner

    if mappable_objects.any?
      render_map_container
      render_legend
    else
      render_nothing_to_map
    end
  end

  private

  # --------------------------------------------------------------
  # Object filtering / nothing-to-map fallback
  # --------------------------------------------------------------

  def mappable_objects
    @mappable_objects ||= @objects.reject do |obj|
      name = obj.respond_to?(:location) ? obj.location&.name : obj.name
      Location.is_unknown?(name)
    end
  end

  def nothing_to_map_text
    @nothing_to_map || :runtime_map_nothing_to_map.t
  end

  # `nothing_to_map_text` is typically a `:foo.tp` textile-processed
  # html_safe string (e.g. with `<em>` tags around model names),
  # so emit through `trusted_html` rather than `plain` which would
  # escape the entities.
  def render_nothing_to_map
    div(class: "w-100") { trusted_html(nothing_to_map_text) }
  end

  # --------------------------------------------------------------
  # Cap banner
  # --------------------------------------------------------------

  # The banner is only meaningful when the dataset was clustered (the
  # cap only kicks in on the clustering path). Skip the emit entirely
  # when either count is missing so the helper-era output shape is
  # preserved for non-cap callers.
  def render_cap_banner
    return unless @clustering
    return if @observations_loaded_count.nil? ||
              @observations_total_count.nil?

    div(id: "map_cap_banner", class: "alert alert-warning mt-2",
        style: (@capped ? nil : "display:none")) do
      trusted_html(
        :map_cap_banner.t(
          loaded: @observations_loaded_count.to_fs(:delimited),
          total: @observations_total_count.to_fs(:delimited)
        )
      )
    end
  end

  # --------------------------------------------------------------
  # Map container + data attributes
  # --------------------------------------------------------------

  def render_map_container
    div(class: "w-100 position-relative map-container") do
      div(id: @map_div,
          class: "position-absolute w-100 h-100",
          data: map_data_attributes)
    end
  end

  def map_data_attributes
    base_map_data_attributes.merge(optional_map_data_attributes)
  end

  def base_map_data_attributes
    {
      map_target: @map_target,
      map_type: @map_type,
      need_elevations_value: @need_elevations_value.to_s,
      map_open: @map_open.to_s,
      editable: @editable.to_s,
      controls: @controls.to_json,
      location_format: location_format_value,
      collection: collection_for_js.to_json,
      localization: localization_data.to_json
    }
  end

  def optional_map_data_attributes
    attrs = {}
    attrs[:controller] = @controller if @controller
    attrs[:zoom] = @zoom.to_s if @zoom
    attrs[:cluster_query_string] = @cluster_query_string if
      @cluster_query_string
    attrs[:clustering] = "true" if use_clustering?
    attrs[:capped] = "true" if @capped
    attrs
  end

  # Location format — caller wins, then the prop'd user's preference,
  # then the global `::User.current` fallback (the helper-era path),
  # then the "postal" baseline. The `::User` qualifier matches the
  # same fallback the deleted `MapHelper#default_map_args` used and
  # keeps the NoUserCurrentInViews cop quiet on a pre-existing path.
  def location_format_value
    @location_format || @user&.location_format ||
      ::User.current_location_format || "postal"
  end

  # Localization values shipped to the JS controller as a JSON blob on
  # `data-localization`. Includes the cap-banner template — looked up
  # via the raw `I18n.t` call (no textile processing) so the JS can
  # substitute `[loaded]` / `[total]` on every viewport refetch.
  def localization_data
    {
      nothing_to_map: nothing_to_map_text,
      observations: :Observations.t,
      locations: :Locations.t,
      show_all: :show_all.t,
      map_all: :map_all.t,
      map_cap_banner: I18n.t("#{MO.locale_namespace}.map_cap_banner")
    }
  end

  # --------------------------------------------------------------
  # Marker tooltip title
  # --------------------------------------------------------------

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
        observation_location_string(obj)
      end
    end.uniq
  end

  def observation_location_string(obs)
    if obs.location
      obs.location.display_name
    elsif obs.lat
      "#{format_latitude(obs.lat)} #{format_longitude(obs.lng)}"
    end
  end

  def query_path_params
    effective_query_param ? { q: effective_query_param } : {}
  end

  # The query the user is navigating — explicit `@query` prop when
  # given, otherwise the controller's `current_query` (session +
  # `params[:q]`-derived). Memoized so popup builders don't re-ask
  # per mapset.
  def effective_query
    @effective_query ||= @query || current_query
  end

  # The URL `q=` Hash, derived from `effective_query.q_param`.
  def effective_query_param
    @effective_query_param ||= effective_query&.q_param
  end

  # Plain-text coordinate formatters for marker titles. The popup
  # uses the same shape via `Components::Map::Popup`; kept here too
  # so the marker title computed by `mapset_marker_title` doesn't
  # need the popup class loaded.
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

  # Rendering modules live in their own files (`app/components/map/`).
  # Listed at the bottom of the class body so the constants they
  # reference (`CLUSTER_MAX_OBJECTS`) are defined when their bodies
  # first execute.
  include Clustering
  include Legend
end
